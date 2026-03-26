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
  enable_public_ip   = false
  firezone_id        = var.firezone_id
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
  enable_public_ip   = false
  firezone_id        = var.firezone_id_secondary
  firezone_token     = var.firezone_token_secondary
  log_level          = var.log_level
  tags               = merge(var.tags, { Region = var.secondary_region })
}

# Primary Region Load Balancer
resource "azurerm_public_ip" "firezone_lb_pip_primary" {
  name                = "${var.name_prefix}firezone-lb-pip-primary"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.name_prefix}firezone-primary"
  tags                = var.tags
}

resource "azurerm_lb" "firezone_lb_primary" {
  name                = "${var.name_prefix}firezone-lb-primary"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "firezone-frontend-primary"
    public_ip_address_id = azurerm_public_ip.firezone_lb_pip_primary.id
  }
}

resource "azurerm_lb_backend_address_pool" "firezone_backend_pool_primary" {
  loadbalancer_id = azurerm_lb.firezone_lb_primary.id
  name            = "firezone-backend-pool-primary"
}

resource "azurerm_lb_probe" "firezone_health_probe_primary" {
  loadbalancer_id = azurerm_lb.firezone_lb_primary.id
  name            = "firezone-health-probe-primary"
  port            = 8080
  protocol        = "Http"
  request_path    = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "firezone_wireguard_rule_primary" {
  loadbalancer_id                = azurerm_lb.firezone_lb_primary.id
  name                           = "firezone-wireguard-rule"
  protocol                       = "Udp"
  frontend_port                  = 51820
  backend_port                   = 51820
  frontend_ip_configuration_name = "firezone-frontend-primary"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool_primary.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe_primary.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
}

resource "azurerm_lb_rule" "firezone_health_rule_primary" {
  loadbalancer_id                = azurerm_lb.firezone_lb_primary.id
  name                           = "firezone-health-rule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "firezone-frontend-primary"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool_primary.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe_primary.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

resource "azurerm_network_interface_backend_address_pool_association" "firezone_primary_backend" {
  network_interface_id    = module.firezone_primary.firezone_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.firezone_backend_pool_primary.id
}

# Secondary Region Load Balancer
resource "azurerm_public_ip" "firezone_lb_pip_secondary" {
  name                = "${var.name_prefix}firezone-lb-pip-secondary"
  location            = var.secondary_region
  resource_group_name = var.secondary_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "${var.name_prefix}firezone-secondary"
  tags                = var.tags
}

resource "azurerm_lb" "firezone_lb_secondary" {
  name                = "${var.name_prefix}firezone-lb-secondary"
  location            = var.secondary_region
  resource_group_name = var.secondary_resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "firezone-frontend-secondary"
    public_ip_address_id = azurerm_public_ip.firezone_lb_pip_secondary.id
  }
}

resource "azurerm_lb_backend_address_pool" "firezone_backend_pool_secondary" {
  loadbalancer_id = azurerm_lb.firezone_lb_secondary.id
  name            = "firezone-backend-pool-secondary"
}

resource "azurerm_lb_probe" "firezone_health_probe_secondary" {
  loadbalancer_id = azurerm_lb.firezone_lb_secondary.id
  name            = "firezone-health-probe-secondary"
  port            = 8080
  protocol        = "Http"
  request_path    = "/"
  interval_in_seconds = 15
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "firezone_wireguard_rule_secondary" {
  loadbalancer_id                = azurerm_lb.firezone_lb_secondary.id
  name                           = "firezone-wireguard-rule"
  protocol                       = "Udp"
  frontend_port                  = 51820
  backend_port                   = 51820
  frontend_ip_configuration_name = "firezone-frontend-secondary"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool_secondary.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe_secondary.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 4
}

resource "azurerm_lb_rule" "firezone_health_rule_secondary" {
  loadbalancer_id                = azurerm_lb.firezone_lb_secondary.id
  name                           = "firezone-health-rule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "firezone-frontend-secondary"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.firezone_backend_pool_secondary.id]
  probe_id                       = azurerm_lb_probe.firezone_health_probe_secondary.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

resource "azurerm_network_interface_backend_address_pool_association" "firezone_secondary_backend" {
  network_interface_id    = module.firezone_secondary.firezone_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.firezone_backend_pool_secondary.id
}

# Traffic Manager Profile for Global Load Balancing
resource "azurerm_traffic_manager_profile" "firezone_tm" {
  name                   = "${var.name_prefix}firezone-tm"
  resource_group_name    = var.primary_resource_group_name
  traffic_routing_method = "Performance"
  tags                   = var.tags

  dns_config {
    relative_name = "${var.name_prefix}firezone"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 8080
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }
}

# Traffic Manager Endpoint - Primary Region
resource "azurerm_traffic_manager_azure_endpoint" "firezone_primary" {
  name               = "firezone-primary-endpoint"
  profile_id         = azurerm_traffic_manager_profile.firezone_tm.id
  target_resource_id = azurerm_public_ip.firezone_lb_pip_primary.id
  weight             = 100
  priority           = 1
}

# Traffic Manager Endpoint - Secondary Region
resource "azurerm_traffic_manager_azure_endpoint" "firezone_secondary" {
  name               = "firezone-secondary-endpoint"
  profile_id         = azurerm_traffic_manager_profile.firezone_tm.id
  target_resource_id = azurerm_public_ip.firezone_lb_pip_secondary.id
  weight             = 100
  priority           = 2
}