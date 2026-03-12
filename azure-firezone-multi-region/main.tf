# Multi-Region Firezone Gateway Deployment with Load Balancer
# Deploys Firezone gateways in two regions with Azure Load Balancer

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

# Primary Region Firezone Gateway
module "firezone_primary" {
  source = "../azure-firezone-gateway"

  name_prefix         = "${var.name_prefix}primary-"
  resource_group_name = var.primary_resource_group_name
  vnet_name          = var.primary_vnet_name
  subnet_name        = var.primary_subnet_name
  vm_size            = var.vm_size
  ssh_public_key     = var.ssh_public_key
  enable_public_ip   = false  # Use load balancer IP
  firezone_token     = var.firezone_token
  log_level          = var.log_level
  tags               = merge(var.tags, { Region = var.primary_region })
}

# Secondary Region Firezone Gateway
module "firezone_secondary" {
  source = "../azure-firezone-gateway"

  name_prefix         = "${var.name_prefix}secondary-"
  resource_group_name = var.secondary_resource_group_name
  vnet_name          = var.secondary_vnet_name
  subnet_name        = var.secondary_subnet_name
  vm_size            = var.vm_size
  ssh_public_key     = var.ssh_public_key
  enable_public_ip   = false  # Use load balancer IP
  firezone_token     = var.firezone_token
  log_level          = var.log_level
  tags               = merge(var.tags, { Region = var.secondary_region })
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "firezone_lb_pip" {
  name                = "${var.name_prefix}firezone-lb-pip"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Load Balancer for Firezone Gateways
resource "azurerm_lb" "firezone_lb" {
  name                = "${var.name_prefix}firezone-lb"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "firezone-frontend"
    public_ip_address_id = azurerm_public_ip.firezone_lb_pip.id
  }
}

# Backend Address Pool for Firezone Gateways
resource "azurerm_lb_backend_address_pool" "firezone_backend_pool" {
  loadbalancer_id = azurerm_lb.firezone_lb.id
  name            = "firezone-backend-pool"
}

# Health Probe for Firezone Gateways
resource "azurerm_lb_probe" "firezone_health_probe" {
  loadbalancer_id = azurerm_lb.firezone_lb.id
  name            = "firezone-health-probe"
  port            = 8080
  protocol        = "Http"
  request_path    = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Load Balancing Rule for WireGuard (UDP)
resource "azurerm_lb_rule" "firezone_wireguard_rule" {
  loadbalancer_id                = azurerm_lb.firezone_lb.id
  name                           = "firezone-wireguard-rule"
  protocol                       = "Udp"
  frontend_port                  = 51820
  backend_port                   = 51820
  frontend_ip_configuration_name = "firezone-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
}

# Load Balancing Rule for Health Check (HTTP)
resource "azurerm_lb_rule" "firezone_health_rule" {
  loadbalancer_id                = azurerm_lb.firezone_lb.id
  name                           = "firezone-health-rule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "firezone-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

# Backend Address Pool Association - Primary (using NIC)
resource "azurerm_network_interface_backend_address_pool_association" "firezone_primary_backend" {
  network_interface_id    = module.firezone_primary.firezone_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.firezone_backend_pool.id
}

# Backend Address Pool Association - Secondary (using NIC)
resource "azurerm_network_interface_backend_address_pool_association" "firezone_secondary_backend" {
  network_interface_id    = module.firezone_secondary.firezone_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.firezone_backend_pool.id
}