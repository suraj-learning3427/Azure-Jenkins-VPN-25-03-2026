# Outputs for Azure Firezone Gateway

output "firezone_gateway" {
  description = "Firezone gateway VM information"
  value = {
    id                = azurerm_linux_virtual_machine.firezone_gateway.id
    name              = azurerm_linux_virtual_machine.firezone_gateway.name
    private_ip_address = azurerm_network_interface.firezone_nic.private_ip_address
    public_ip_address = var.enable_public_ip ? azurerm_public_ip.firezone_pip[0].ip_address : null
    location          = azurerm_linux_virtual_machine.firezone_gateway.location
  }
}

output "network_interface" {
  description = "Firezone gateway network interface information"
  value = {
    id                = azurerm_network_interface.firezone_nic.id
    name              = azurerm_network_interface.firezone_nic.name
    private_ip_address = azurerm_network_interface.firezone_nic.private_ip_address
  }
}

output "firezone_nic" {
  description = "Firezone gateway network interface resource"
  value       = azurerm_network_interface.firezone_nic
}

output "public_ip" {
  description = "Firezone gateway public IP information"
  value = var.enable_public_ip ? {
    id         = azurerm_public_ip.firezone_pip[0].id
    name       = azurerm_public_ip.firezone_pip[0].name
    ip_address = azurerm_public_ip.firezone_pip[0].ip_address
    fqdn       = azurerm_public_ip.firezone_pip[0].fqdn
  } : null
}

output "user_identity" {
  description = "Firezone gateway user assigned identity information"
  value = {
    id           = azurerm_user_assigned_identity.firezone_identity.id
    name         = azurerm_user_assigned_identity.firezone_identity.name
    principal_id = azurerm_user_assigned_identity.firezone_identity.principal_id
    client_id    = azurerm_user_assigned_identity.firezone_identity.client_id
  }
}

output "gateway_access_info" {
  description = "Firezone gateway access information"
  value = {
    wireguard_endpoint = var.enable_public_ip ? "${azurerm_public_ip.firezone_pip[0].ip_address}:51820" : "${azurerm_network_interface.firezone_nic.private_ip_address}:51820"
    health_check_url   = var.enable_public_ip ? "http://${azurerm_public_ip.firezone_pip[0].ip_address}:8080" : "http://${azurerm_network_interface.firezone_nic.private_ip_address}:8080"
    ssh_access         = var.enable_public_ip ? "ssh azureuser@${azurerm_public_ip.firezone_pip[0].ip_address}" : "ssh azureuser@${azurerm_network_interface.firezone_nic.private_ip_address}"
  }
}