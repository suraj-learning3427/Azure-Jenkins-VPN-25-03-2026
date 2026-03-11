# Outputs for Multi-Region Firezone Gateway Deployment

output "load_balancer" {
  description = "Firezone load balancer information"
  value = {
    id                = azurerm_lb.firezone_lb.id
    name              = azurerm_lb.firezone_lb.name
    public_ip_address = azurerm_public_ip.firezone_lb_pip.ip_address
    fqdn              = azurerm_public_ip.firezone_lb_pip.fqdn
  }
}

output "firezone_primary" {
  description = "Primary Firezone gateway information"
  value = {
    vm_id             = module.firezone_primary.firezone_gateway.id
    vm_name           = module.firezone_primary.firezone_gateway.name
    private_ip        = module.firezone_primary.firezone_gateway.private_ip_address
    region            = var.primary_region
    resource_group    = var.primary_resource_group_name
  }
}

output "firezone_secondary" {
  description = "Secondary Firezone gateway information"
  value = {
    vm_id             = module.firezone_secondary.firezone_gateway.id
    vm_name           = module.firezone_secondary.firezone_gateway.name
    private_ip        = module.firezone_secondary.firezone_gateway.private_ip_address
    region            = var.secondary_region
    resource_group    = var.secondary_resource_group_name
  }
}

output "firezone_access_info" {
  description = "Firezone access information"
  value = {
    wireguard_endpoint    = "${azurerm_public_ip.firezone_lb_pip.ip_address}:51820"
    health_check_url      = "http://${azurerm_public_ip.firezone_lb_pip.ip_address}:8080"
    primary_gateway_ip    = module.firezone_primary.firezone_gateway.private_ip_address
    secondary_gateway_ip  = module.firezone_secondary.firezone_gateway.private_ip_address
    load_balancer_ip      = azurerm_public_ip.firezone_lb_pip.ip_address
  }
}