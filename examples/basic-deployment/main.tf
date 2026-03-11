# Basic Azure Firezone Gateway Deployment Example
# Equivalent to GCP NAT gateway example

provider "azurerm" {
  features {}
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "example" {
  name     = "${var.name_prefix}firezone-example-rg"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "example" {
  name                = "${var.name_prefix}firezone-vnet"
  address_space       = ["172.20.0.0/16"]
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}

# Gateway Subnet
resource "azurerm_subnet" "gateway" {
  name                 = "gateway-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["172.20.1.0/24"]
}

# Application Gateway Subnet (if load balancer enabled)
resource "azurerm_subnet" "appgw" {
  count                = var.enable_load_balancer ? 1 : 0
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["172.20.2.0/24"]
}

# NAT Gateway for outbound connectivity (optional)
resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${var.name_prefix}nat-gateway-pip"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "example" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${var.name_prefix}nat-gateway"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "example" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.example[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "example" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.gateway.id
  nat_gateway_id = azurerm_nat_gateway.example[0].id
}

# SSH Key Pair (for demonstration - use existing key in production)
resource "tls_private_key" "example" {
  count     = var.ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Firezone Gateway Module
module "firezone_gateway" {
  source = "../.."

  name_prefix = var.name_prefix
  location    = azurerm_resource_group.example.location

  # Networking
  subnet_id         = azurerm_subnet.gateway.id
  gateway_subnet_id = var.enable_load_balancer ? azurerm_subnet.appgw[0].id : null
  enable_public_ip  = var.enable_public_ip
  enable_load_balancer = var.enable_load_balancer

  # VM Configuration
  vm_size        = var.vm_size
  instance_count = var.instance_count
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : tls_private_key.example[0].public_key_openssh

  # Firezone Configuration
  firezone_token        = var.firezone_token
  firezone_api_url      = var.firezone_api_url
  firezone_version      = var.firezone_version
  log_level            = var.log_level
  log_format           = var.log_format

  # Health Check
  health_check = var.health_check

  # Tags
  tags = merge(var.tags, {
    Example = "basic-deployment"
  })

  depends_on = [
    azurerm_subnet.gateway,
    azurerm_subnet_nat_gateway_association.example
  ]
}