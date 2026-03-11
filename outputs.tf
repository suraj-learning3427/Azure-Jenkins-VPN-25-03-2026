# Azure Jenkins Infrastructure - Root Outputs

output "hub_network" {
  description = "Hub network information"
  value       = module.azure_networking_global
}

# STEP 2: SPOKE NETWORK OUTPUT - ENABLED
output "spoke_network" {
  description = "Spoke network information"
  value       = module.azure_core_infrastructure
}

# STEP 3: JENKINS VM OUTPUT - ENABLED (Single VM Only)
output "jenkins_vm" {
  description = "Jenkins VM information"
  value       = module.azure_jenkins_vm
  sensitive   = true
}

# Firezone Multi-Region Outputs
output "firezone_multi_region" {
  description = "Multi-region Firezone VPN gateway deployment information"
  value       = var.enable_firezone_multi_region ? module.azure_firezone_multi_region[0] : null
  sensitive   = true
}

output "secondary_infrastructure" {
  description = "Secondary region infrastructure information for Firezone"
  value       = var.enable_firezone_multi_region ? module.azure_core_infrastructure_secondary[0] : null
}

# output "application_gateway" {
#   description = "Application Gateway information"
#   value       = module.azure_jenkins_appgw
# }

# output "jenkins_access_info" {
#   description = "Information for accessing Jenkins"
#   value = {
#     jenkins_url           = "https://${var.jenkins_fqdn}"
#     application_gateway_ip = var.jenkins_static_ip
#     bastion_access        = module.azure_networking_global.bastion_host
#   }
# }