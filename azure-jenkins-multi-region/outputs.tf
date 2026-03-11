# Outputs for Multi-Region Jenkins Deployment

output "load_balancer" {
  description = "Load balancer information"
  value = {
    id                = azurerm_lb.jenkins_lb.id
    name              = azurerm_lb.jenkins_lb.name
    public_ip_address = azurerm_public_ip.lb_public_ip.ip_address
    fqdn              = azurerm_public_ip.lb_public_ip.fqdn
  }
}

output "jenkins_primary" {
  description = "Primary Jenkins VM information"
  value = {
    vm_id             = module.jenkins_primary.jenkins_vm.id
    vm_name           = module.jenkins_primary.jenkins_vm.name
    private_ip        = module.jenkins_primary.jenkins_vm.private_ip_address
    region            = var.primary_region
    resource_group    = var.primary_resource_group_name
  }
  sensitive = true
}

output "jenkins_secondary" {
  description = "Secondary Jenkins VM information"
  value = {
    vm_id             = module.jenkins_secondary.jenkins_vm.id
    vm_name           = module.jenkins_secondary.jenkins_vm.name
    private_ip        = module.jenkins_secondary.jenkins_vm.private_ip_address
    region            = var.secondary_region
    resource_group    = var.secondary_resource_group_name
  }
  sensitive = true
}

output "jenkins_access_info" {
  description = "Jenkins access information"
  value = {
    load_balancer_url = "http://${azurerm_public_ip.lb_public_ip.ip_address}"
    primary_vm_url    = "http://${module.jenkins_primary.jenkins_vm.private_ip_address}:${var.jenkins_port}"
    secondary_vm_url  = "http://${module.jenkins_secondary.jenkins_vm.private_ip_address}:${var.jenkins_port}"
    health_check_path = "/login"
  }
}