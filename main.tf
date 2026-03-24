# Azure Jenkins Infrastructure - Root Configuration
# This is the main entry point for deploying the complete Azure infrastructure

terraform {
  required_version = ">= 1.0"

  # Terraform Cloud remote backend — state stored here, plans/applies run here
  cloud {
    organization = "terraform-learningmyway"

    workspaces {
      name = "Azure-Jenkins-Terraform-updated-one"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

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
  location                 = var.location
  spoke_address_space      = var.spoke_address_space
  vpn_subnet_cidr          = var.vpn_subnet_cidr
  enable_hub_peering       = var.enable_hub_peering
  hub_vnet_id              = module.azure_networking_global.hub_virtual_network.id
  hub_resource_group_name  = module.azure_networking_global.resource_group.name
  hub_vnet_name            = module.azure_networking_global.hub_virtual_network.name
  hub_has_gateway          = var.enable_vpn_gateway
  dns_zone_name            = var.dns_zone_name
  firezone_client_cidr     = var.firezone_client_cidr
  tags                     = var.tags

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
  kv_name            = module.certs_keyvault.key_vault_name
  tags               = var.tags

  depends_on = [module.azure_core_infrastructure, module.certs_keyvault]
}

# Secondary Region Infrastructure for Firezone
module "azure_core_infrastructure_secondary" {
  count  = var.enable_firezone_multi_region ? 1 : 0
  source = "./azure-core-infrastructure-secondary"

  name_prefix                  = var.name_prefix
  location                    = var.secondary_region
  spoke_address_space         = var.secondary_spoke_address_space
  jenkins_subnet_cidr         = var.secondary_jenkins_subnet_cidr
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
  firezone_id                   = var.firezone_id
  firezone_token                = var.firezone_token
  tags                          = var.tags

  depends_on = [
    module.azure_core_infrastructure,
    module.azure_core_infrastructure_secondary
  ]
}

# Key Vault for Jenkins TLS Certificates
# Note: Created before Jenkins VM so the KV name can be passed to the VM extension.
# The Jenkins VM managed identity access policy is added after VM creation.
module "certs_keyvault" {
  source = "./azure/certs-keyvault"

  resource_group_name              = module.azure_core_infrastructure.resource_group.name
  jenkins_vm_identity_principal_id = ""
  pfx_password                     = var.pfx_password
  tags                             = var.tags

  depends_on = [module.azure_core_infrastructure]
}

# Grant Jenkins VM managed identity access to Key Vault (added after VM is created)
resource "azurerm_key_vault_access_policy" "jenkins_vm_kv_access" {
  key_vault_id = module.certs_keyvault.key_vault_id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = module.azure_jenkins_vm.jenkins_identity.principal_id

  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]

  depends_on = [module.azure_jenkins_vm, module.certs_keyvault]
}

# Private DNS A Record for Jenkins VM
resource "azurerm_private_dns_a_record" "jenkins" {
  name                = "jenkins-az"
  zone_name           = module.azure_core_infrastructure.private_dns_zone.name
  resource_group_name = module.azure_core_infrastructure.resource_group.name
  ttl                 = 300
  records             = [module.azure_jenkins_vm.jenkins_vm.private_ip_address]

  depends_on = [module.azure_jenkins_vm]
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