output "key_vault_id"   { value = azurerm_key_vault.jenkins_kv.id }
output "key_vault_name" { value = azurerm_key_vault.jenkins_kv.name }
output "key_vault_uri"  { value = azurerm_key_vault.jenkins_kv.vault_uri }
output "jenkins_az_cert_secret_id" { value = length(azurerm_key_vault_certificate.jenkins_az_cert) > 0 ? azurerm_key_vault_certificate.jenkins_az_cert[0].secret_id : "" }
output "root_ca_secret_id"         { value = length(azurerm_key_vault_secret.root_ca_cert) > 0 ? azurerm_key_vault_secret.root_ca_cert[0].id : "" }
