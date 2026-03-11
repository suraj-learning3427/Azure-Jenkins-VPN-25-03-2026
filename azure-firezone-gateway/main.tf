# Azure Firezone Gateway Module
# Creates Firezone VPN gateway equivalent to GCP terraform-google-gateway

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}
data "azurerm_resource_group" "gateway_rg" {
  name = var.resource_group_name
}

data "azurerm_subnet" "gateway_subnet" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

# Public IP for Firezone Gateway
resource "azurerm_public_ip" "firezone_pip" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "${var.name_prefix}firezone-gateway-pip"
  location            = data.azurerm_resource_group.gateway_rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Network Interface for Firezone Gateway
resource "azurerm_network_interface" "firezone_nic" {
  name                = "${var.name_prefix}firezone-gateway-nic"
  location            = data.azurerm_resource_group.gateway_rg.location
  resource_group_name = var.resource_group_name
  enable_ip_forwarding = true
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.gateway_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.firezone_pip[0].id : null
  }
}

# User Assigned Identity for Firezone Gateway
resource "azurerm_user_assigned_identity" "firezone_identity" {
  name                = "${var.name_prefix}firezone-gateway-identity"
  location            = data.azurerm_resource_group.gateway_rg.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Firezone Gateway Virtual Machine
resource "azurerm_linux_virtual_machine" "firezone_gateway" {
  name                = "${var.name_prefix}firezone-gateway"
  location            = data.azurerm_resource_group.gateway_rg.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.firezone_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 32
  }

  # Ubuntu 22.04 LTS (Firezone recommended)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # User assigned identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.firezone_identity.id]
  }

  # Custom data for Firezone installation
  custom_data = base64encode(templatefile("${path.module}/templates/firezone-startup.sh", {
    firezone_token = var.firezone_token
    log_level      = var.log_level
  }))
}