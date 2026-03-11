# Multi-Region Jenkins Deployment with Load Balancer
# Deploys Jenkins VMs in two regions with Azure Load Balancer

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

# Primary Region Jenkins VM
module "jenkins_primary" {
  source = "../azure-jenkins-vm"

  name_prefix         = "${var.name_prefix}primary-"
  resource_group_name = var.primary_resource_group_name
  vnet_name          = var.primary_vnet_name
  subnet_name        = var.primary_subnet_name
  vm_name            = "${var.name_prefix}jenkins-primary"
  vm_size            = var.vm_size
  ssh_public_key     = var.ssh_public_key
  jenkins_port       = var.jenkins_port
  tags               = merge(var.tags, { Region = var.primary_region })
}

# Secondary Region Jenkins VM
module "jenkins_secondary" {
  source = "../azure-jenkins-vm"

  name_prefix         = "${var.name_prefix}secondary-"
  resource_group_name = var.secondary_resource_group_name
  vnet_name          = var.secondary_vnet_name
  subnet_name        = var.secondary_subnet_name
  vm_name            = "${var.name_prefix}jenkins-secondary"
  vm_size            = var.vm_size
  ssh_public_key     = var.ssh_public_key
  jenkins_port       = var.jenkins_port
  tags               = merge(var.tags, { Region = var.secondary_region })
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "${var.name_prefix}jenkins-lb-pip"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Load Balancer
resource "azurerm_lb" "jenkins_lb" {
  name                = "${var.name_prefix}jenkins-lb"
  location            = var.primary_region
  resource_group_name = var.primary_resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                 = "jenkins-frontend"
    public_ip_address_id = azurerm_public_ip.lb_public_ip.id
  }
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "jenkins_backend_pool" {
  loadbalancer_id = azurerm_lb.jenkins_lb.id
  name            = "jenkins-backend-pool"
}

# Health Probe
resource "azurerm_lb_probe" "jenkins_health_probe" {
  loadbalancer_id = azurerm_lb.jenkins_lb.id
  name            = "jenkins-health-probe"
  port            = var.jenkins_port
  protocol        = "Http"
  request_path    = "/login"
  interval_in_seconds = 15
  number_of_probes    = 2
}

# Load Balancing Rule
resource "azurerm_lb_rule" "jenkins_lb_rule" {
  loadbalancer_id                = azurerm_lb.jenkins_lb.id
  name                           = "jenkins-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = var.jenkins_port
  frontend_ip_configuration_name = "jenkins-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.jenkins_backend_pool.id]
  probe_id                       = azurerm_lb_probe.jenkins_health_probe.id
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 15
}

# Backend Address Pool Association - Primary
resource "azurerm_lb_backend_address_pool_address" "jenkins_primary_backend" {
  name                    = "jenkins-primary-backend"
  backend_address_pool_id = azurerm_lb_backend_address_pool.jenkins_backend_pool.id
  virtual_network_id      = var.primary_vnet_id
  ip_address              = module.jenkins_primary.jenkins_vm.private_ip_address
}

# Backend Address Pool Association - Secondary
resource "azurerm_lb_backend_address_pool_address" "jenkins_secondary_backend" {
  name                    = "jenkins-secondary-backend"
  backend_address_pool_id = azurerm_lb_backend_address_pool.jenkins_backend_pool.id
  virtual_network_id      = var.secondary_vnet_id
  ip_address              = module.jenkins_secondary.jenkins_vm.private_ip_address
}