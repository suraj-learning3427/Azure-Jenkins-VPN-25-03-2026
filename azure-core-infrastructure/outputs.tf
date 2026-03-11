# Outputs for Azure Core Infrastructure (Spoke)

output "resource_group" {
  description = "Core infrastructure resource group information"
  value = {
    name     = azurerm_resource_group.core_infrastructure.name
    location = azurerm_resource_group.core_infrastructure.location
    id       = azurerm_resource_group.core_infrastructure.id
  }
}

output "spoke_virtual_network" {
  description = "Spoke virtual network information"
  value = {
    name          = azurerm_virtual_network.vpc_spoke.name
    id            = azurerm_virtual_network.vpc_spoke.id
    address_space = azurerm_virtual_network.vpc_spoke.address_space
  }
}

output "jenkins_subnet" {
  description = "Jenkins subnet information"
  value = {
    name             = azurerm_subnet.subnet_jenkins.name
    id               = azurerm_subnet.subnet_jenkins.id
    address_prefixes = azurerm_subnet.subnet_jenkins.address_prefixes
  }
}

output "appgw_subnet" {
  description = "Application Gateway subnet information"
  value = {
    name             = azurerm_subnet.subnet_appgw.name
    id               = azurerm_subnet.subnet_appgw.id
    address_prefixes = azurerm_subnet.subnet_appgw.address_prefixes
  }
}

output "vpn_subnet" {
  description = "VPN subnet information for Firezone gateway"
  value = {
    name             = azurerm_subnet.subnet_vpn.name
    id               = azurerm_subnet.subnet_vpn.id
    address_prefixes = azurerm_subnet.subnet_vpn.address_prefixes
  }
}

output "jenkins_nsg" {
  description = "Jenkins network security group information"
  value = {
    name = azurerm_network_security_group.jenkins_nsg.name
    id   = azurerm_network_security_group.jenkins_nsg.id
  }
}

output "appgw_nsg" {
  description = "Application Gateway network security group information"
  value = {
    name = azurerm_network_security_group.appgw_nsg.name
    id   = azurerm_network_security_group.appgw_nsg.id
  }
}

output "private_dns_zone" {
  description = "Private DNS zone information"
  value = {
    name = azurerm_private_dns_zone.jenkins_dns.name
    id   = azurerm_private_dns_zone.jenkins_dns.id
  }
}

output "vnet_peering" {
  description = "VNet peering information (if enabled)"
  value = var.enable_hub_peering ? {
    name = azurerm_virtual_network_peering.spoke_to_hub[0].name
    id   = azurerm_virtual_network_peering.spoke_to_hub[0].id
  } : null
}