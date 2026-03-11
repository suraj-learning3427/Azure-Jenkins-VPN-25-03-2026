# Outputs for Basic Azure Firezone Gateway Deployment Example

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.example.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.example.id
}

output "gateway_subnet_id" {
  description = "ID of the gateway subnet"
  value       = azurerm_subnet.gateway.id
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway"
  value       = var.enable_nat_gateway ? azurerm_public_ip.nat[0].ip_address : null
}

output "firezone_gateway" {
  description = "Firezone gateway module outputs"
  value       = module.firezone_gateway
  sensitive   = true
}

output "ssh_private_key" {
  description = "Generated SSH private key (if created)"
  value       = var.ssh_public_key == "" ? tls_private_key.example[0].private_key_pem : null
  sensitive   = true
}

output "connection_info" {
  description = "Information for connecting to the deployment"
  value = {
    gateway_endpoint = module.firezone_gateway.public_ip
    health_check_url = module.firezone_gateway.gateway_endpoints.health_check_url
    ssh_command      = var.ssh_public_key == "" ? "Use the generated private key to SSH" : "ssh ${var.admin_username}@<instance-ip>"
  }
}