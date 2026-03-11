# Outputs for Azure Jenkins Application Gateway

output "application_gateway" {
  description = "Application Gateway information"
  value = {
    name                = azurerm_application_gateway.jenkins_appgw.name
    id                  = azurerm_application_gateway.jenkins_appgw.id
    private_ip_address  = var.static_private_ip
    public_ip_address   = var.enable_public_ip ? azurerm_public_ip.appgw_pip[0].ip_address : null
  }
}

output "key_vault" {
  description = "Key Vault information"
  value = {
    name = azurerm_key_vault.jenkins_kv.name
    id   = azurerm_key_vault.jenkins_kv.id
    uri  = azurerm_key_vault.jenkins_kv.vault_uri
  }
}

output "ssl_certificate" {
  description = "SSL certificate information"
  value = {
    name       = azurerm_key_vault_certificate.jenkins_cert.name
    id         = azurerm_key_vault_certificate.jenkins_cert.id
    secret_id  = azurerm_key_vault_certificate.jenkins_cert.secret_id
    thumbprint = azurerm_key_vault_certificate.jenkins_cert.thumbprint
  }
}

output "appgw_identity" {
  description = "Application Gateway user assigned identity"
  value = {
    id           = azurerm_user_assigned_identity.appgw_identity.id
    principal_id = azurerm_user_assigned_identity.appgw_identity.principal_id
    client_id    = azurerm_user_assigned_identity.appgw_identity.client_id
  }
}

output "jenkins_access_info" {
  description = "Information for accessing Jenkins through Application Gateway"
  value = {
    private_https_url = "https://${var.static_private_ip}"
    public_https_url  = var.enable_public_ip ? "https://${azurerm_public_ip.appgw_pip[0].ip_address}" : null
    fqdn_url         = "https://${var.jenkins_fqdn}"
    health_check_url = "http://${var.static_private_ip}${var.health_check_path}"
  }
}