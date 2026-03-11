# Azure Networking Global (Hub) - Equivalent to GCP Networkingglobal
# Creates the hub network infrastructure for Azure

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group for Hub Network
resource "azurerm_resource_group" "networking_global" {
  name     = "${var.name_prefix}networking-global-rg"
  location = var.location
  tags     = var.tags
}

# Hub Virtual Network (equivalent to vpc-hub)
resource "azurerm_virtual_network" "vpc_hub" {
  name                = "${var.name_prefix}vpc-hub"
  address_space       = [var.hub_address_space]
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  tags                = var.tags
}

# VPN Gateway Subnet (equivalent to subnet-vpn)
resource "azurerm_subnet" "subnet_vpn" {
  name                 = "subnet-vpn"
  resource_group_name  = azurerm_resource_group.networking_global.name
  virtual_network_name = azurerm_virtual_network.vpc_hub.name
  address_prefixes     = [var.vpn_subnet_cidr]
}

# Gateway Subnet for VPN Gateway (required by Azure)
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"  # Must be exactly "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networking_global.name
  virtual_network_name = azurerm_virtual_network.vpc_hub.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# Network Security Group for Hub
resource "azurerm_network_security_group" "hub_nsg" {
  name                = "${var.name_prefix}hub-nsg"
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  tags                = var.tags

  # Allow SSH from Azure Bastion (equivalent to IAP)
  security_rule {
    name                       = "AllowBastionSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow WireGuard/Firezone traffic (equivalent to allow-firezone-udp)
  security_rule {
    name                       = "AllowWireGuard"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "51820"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTPS from spoke networks
  security_rule {
    name                       = "AllowSpokeHTTPS"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefixes    = var.spoke_address_spaces
    destination_address_prefix = "*"
  }
}

# Associate NSG with VPN subnet
resource "azurerm_subnet_network_security_group_association" "vpn_subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet_vpn.id
  network_security_group_id = azurerm_network_security_group.hub_nsg.id
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway_pip" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${var.name_prefix}vpn-gateway-pip"
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# VPN Gateway (equivalent to Firezone gateway)
resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  count               = var.enable_vpn_gateway ? 1 : 0
  name                = "${var.name_prefix}vpn-gateway"
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  tags                = var.tags

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = false
  enable_bgp    = false
  sku           = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway_pip[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway_subnet.id
  }
}

# Azure Bastion for secure access (equivalent to IAP)
resource "azurerm_subnet" "bastion_subnet" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"  # Must be exactly "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networking_global.name
  virtual_network_name = azurerm_virtual_network.vpc_hub.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

resource "azurerm_public_ip" "bastion_pip" {
  count               = var.enable_bastion ? 1 : 0
  name                = "${var.name_prefix}bastion-pip"
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion" {
  count               = var.enable_bastion ? 1 : 0
  name                = "${var.name_prefix}bastion"
  location            = azurerm_resource_group.networking_global.location
  resource_group_name = azurerm_resource_group.networking_global.name
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion_subnet[0].id
    public_ip_address_id = azurerm_public_ip.bastion_pip[0].id
  }
}