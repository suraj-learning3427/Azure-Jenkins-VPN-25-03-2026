# Azure Core Infrastructure (Secondary Region)
# Creates spoke network infrastructure in secondary region

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

# Resource Group for Secondary Region
resource "azurerm_resource_group" "core_infrastructure_secondary" {
  name     = "${var.name_prefix}core-infrastructure-secondary-rg"
  location = var.location
  tags     = var.tags
}

# Spoke Virtual Network (Secondary Region)
resource "azurerm_virtual_network" "vpc_spoke_secondary" {
  name                = "${var.name_prefix}vpc-spoke-secondary"
  address_space       = [var.spoke_address_space]
  location            = azurerm_resource_group.core_infrastructure_secondary.location
  resource_group_name = azurerm_resource_group.core_infrastructure_secondary.name
  tags                = var.tags
}

# Jenkins Subnet (Secondary Region)
resource "azurerm_subnet" "subnet_jenkins_secondary" {
  name                 = "subnet-jenkins"
  resource_group_name  = azurerm_resource_group.core_infrastructure_secondary.name
  virtual_network_name = azurerm_virtual_network.vpc_spoke_secondary.name
  address_prefixes     = [var.jenkins_subnet_cidr]
}

# VPN Subnet for Firezone Gateway (Secondary Region)
resource "azurerm_subnet" "subnet_vpn_secondary" {
  name                 = "subnet-vpn"
  resource_group_name  = azurerm_resource_group.core_infrastructure_secondary.name
  virtual_network_name = azurerm_virtual_network.vpc_spoke_secondary.name
  address_prefixes     = [var.vpn_subnet_cidr]
}

# Network Security Group for Jenkins (Secondary Region)
resource "azurerm_network_security_group" "jenkins_nsg_secondary" {
  name                = "${var.name_prefix}jenkins-nsg-secondary"
  location            = azurerm_resource_group.core_infrastructure_secondary.location
  resource_group_name = azurerm_resource_group.core_infrastructure_secondary.name
  tags                = var.tags

  # Allow SSH access
  security_rule {
    name                       = "AllowSSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow Jenkins port
  security_rule {
    name                       = "AllowJenkins"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = var.jenkins_port
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP for load balancer health checks
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with Jenkins subnet
resource "azurerm_subnet_network_security_group_association" "jenkins_subnet_nsg_secondary" {
  subnet_id                 = azurerm_subnet.subnet_jenkins_secondary.id
  network_security_group_id = azurerm_network_security_group.jenkins_nsg_secondary.id
}

# VNet Peering to Primary Region (if enabled)
resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  count                        = var.enable_primary_peering ? 1 : 0
  name                         = "secondary-to-primary-peering"
  resource_group_name          = azurerm_resource_group.core_infrastructure_secondary.name
  virtual_network_name         = azurerm_virtual_network.vpc_spoke_secondary.name
  remote_virtual_network_id    = var.primary_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Reverse VNet Peering from Primary to Secondary
resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  count                        = var.enable_primary_peering ? 1 : 0
  name                         = "primary-to-secondary-peering"
  resource_group_name          = var.primary_resource_group_name
  virtual_network_name         = var.primary_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.vpc_spoke_secondary.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false

  depends_on = [azurerm_virtual_network_peering.secondary_to_primary]
}