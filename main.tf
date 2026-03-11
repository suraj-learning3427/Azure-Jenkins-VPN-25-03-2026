# Azure Jenkins Infrastructure - Root Configuration
# This is the main entry point for deploying the complete Azure infrastructure

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Hub Network Module
module "azure_networking_global" {
  source = "./azure-networking-global"

  name_prefix           = var.name_prefix
  location             = var.location
  hub_address_space    = var.hub_address_space
  enable_bastion       = var.enable_bastion
  enable_vpn_gateway   = var.enable_vpn_gateway
  tags                 = var.tags
}

# Spoke Network Module - STEP 2: DEPLOYING NOW
module "azure_core_infrastructure" {
  source = "./azure-core-infrastructure"

  name_prefix              = var.name_prefix
  location                = var.location
  spoke_address_space     = var.spoke_address_space
  vpn_subnet_cidr         = var.vpn_subnet_cidr
  enable_hub_peering      = var.enable_hub_peering
  hub_vnet_id             = module.azure_networking_global.hub_virtual_network.id
  hub_resource_group_name = module.azure_networking_global.resource_group.name
  hub_vnet_name           = module.azure_networking_global.hub_virtual_network.name
  hub_has_gateway         = var.enable_vpn_gateway
  tags                    = var.tags

  depends_on = [module.azure_networking_global]
}

# Jenkins VM Module - STEP 3: DEPLOYING NOW
module "azure_jenkins_vm" {
  source = "./azure-jenkins-vm"

  name_prefix         = var.name_prefix
  resource_group_name = module.azure_core_infrastructure.resource_group.name
  vnet_name          = module.azure_core_infrastructure.spoke_virtual_network.name
  ssh_public_key     = var.ssh_public_key
  vm_size            = var.jenkins_vm_size
  tags               = var.tags

  depends_on = [module.azure_core_infrastructure]
}

# Secondary Region Infrastructure for Firezone
module "azure_core_infrastructure_secondary" {
  count  = var.enable_firezone_multi_region ? 1 : 0
  source = "./azure-core-infrastructure-secondary"

  name_prefix                  = var.name_prefix
  location                    = var.secondary_region
  spoke_address_space         = var.secondary_spoke_address_space
  vpn_subnet_cidr             = var.secondary_vpn_subnet_cidr
  enable_primary_peering      = true
  primary_vnet_id             = module.azure_core_infrastructure.spoke_virtual_network.id
  primary_resource_group_name = module.azure_core_infrastructure.resource_group.name
  primary_vnet_name           = module.azure_core_infrastructure.spoke_virtual_network.name
  tags                        = var.tags

  depends_on = [module.azure_core_infrastructure]
}

# Multi-Region Firezone VPN Gateway Deployment
module "azure_firezone_multi_region" {
  count  = var.enable_firezone_multi_region ? 1 : 0
  source = "./azure-firezone-multi-region"

  name_prefix                     = var.name_prefix
  primary_region                  = var.location
  primary_resource_group_name     = module.azure_core_infrastructure.resource_group.name
  primary_vnet_name              = module.azure_core_infrastructure.spoke_virtual_network.name
  primary_vnet_id                = module.azure_core_infrastructure.spoke_virtual_network.id
  primary_subnet_name            = module.azure_core_infrastructure.vpn_subnet.name
  secondary_region               = var.secondary_region
  secondary_resource_group_name  = module.azure_core_infrastructure_secondary[0].resource_group.name
  secondary_vnet_name           = module.azure_core_infrastructure_secondary[0].spoke_virtual_network.name
  secondary_vnet_id             = module.azure_core_infrastructure_secondary[0].spoke_virtual_network.id
  secondary_subnet_name         = module.azure_core_infrastructure_secondary[0].vpn_subnet.name
  vm_size                       = "Standard_B2s"
  ssh_public_key                = var.ssh_public_key
  firezone_token                = var.firezone_token
  tags                          = var.tags

  depends_on = [
    module.azure_core_infrastructure,
    module.azure_core_infrastructure_secondary
  ]
}

# Application Gateway Module - COMMENTED OUT FOR STEP-BY-STEP DEPLOYMENT
# module "azure_jenkins_appgw" {
#   source = "./azure-jenkins-appgw"

#   name_prefix         = var.name_prefix
#   resource_group_name = module.azure_core_infrastructure.resource_group.name
#   vnet_name          = module.azure_core_infrastructure.spoke_virtual_network.name
#   jenkins_private_ip = module.azure_jenkins_vm.jenkins_vm.private_ip_address
#   static_private_ip  = var.jenkins_static_ip
#   jenkins_fqdn       = var.jenkins_fqdn
#   tags               = var.tags

#   depends_on = [module.azure_jenkins_vm]
# }