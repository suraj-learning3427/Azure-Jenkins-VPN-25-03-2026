# Outputs for Azure Core Infrastructure (Secondary Region)

output "resource_group" {
  description = "Secondary region resource group information"
  value = {
    id       = azurerm_resource_group.core_infrastructure_secondary.id
    name     = azurerm_resource_group.core_infrastructure_secondary.name
    location = azurerm_resource_group.core_infrastructure_secondary.location
  }
}

output "spoke_virtual_network" {
  description = "Secondary region spoke virtual network information"
  value = {
    id            = azurerm_virtual_network.vpc_spoke_secondary.id
    name          = azurerm_virtual_network.vpc_spoke_secondary.name
    address_space = azurerm_virtual_network.vpc_spoke_secondary.address_space
  }
}

output "jenkins_subnet" {
  description = "Secondary region Jenkins subnet information"
  value = {
    id               = azurerm_subnet.subnet_jenkins_secondary.id
    name             = azurerm_subnet.subnet_jenkins_secondary.name
    address_prefixes = azurerm_subnet.subnet_jenkins_secondary.address_prefixes
  }
}

output "vpn_subnet" {
  description = "Secondary region VPN subnet information for Firezone gateway"
  value = {
    id               = azurerm_subnet.subnet_vpn_secondary.id
    name             = azurerm_subnet.subnet_vpn_secondary.name
    address_prefixes = azurerm_subnet.subnet_vpn_secondary.address_prefixes
  }
}

output "jenkins_nsg" {
  description = "Secondary region Jenkins network security group information"
  value = {
    id   = azurerm_network_security_group.jenkins_nsg_secondary.id
    name = azurerm_network_security_group.jenkins_nsg_secondary.name
  }
}