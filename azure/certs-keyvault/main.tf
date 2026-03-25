terraform {
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

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# ─── KEY VAULT ────────────────────────────────────────────────────────────────
resource "azurerm_key_vault" "jenkins_kv" {
  name                       = "jenkins-certs-kv-${random_string.kv_suffix.result}"
  location                   = data.azurerm_resource_group.rg.location
  resource_group_name        = data.azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  # Terraform deployer access
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = ["Backup", "Create", "Delete", "DeleteIssuers", "Get", "GetIssuers",
      "Import", "List", "ListIssuers", "ManageContacts", "ManageIssuers", "Purge", "Recover",
      "Restore", "SetIssuers", "Update"]
    secret_permissions      = ["Backup", "Delete", "Get", "List", "Purge", "Recover", "Restore", "Set"]
    key_permissions         = ["Backup", "Create", "Decrypt", "Delete", "Encrypt", "Get", "Import",
      "List", "Purge", "Recover", "Restore", "Sign", "UnwrapKey", "Update", "Verify", "WrapKey"]
  }
}

# ─── ROOT CA CERT ─────────────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "root_ca_cert" {
  name         = "root-ca-cert"
  value        = var.root_ca_cert_pem
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  content_type = "application/x-pem-file"
  tags         = merge(var.tags, { cert-type = "root-ca" })
}

# ─── INTERMEDIATE CA CERT ─────────────────────────────────────────────────────
resource "azurerm_key_vault_secret" "intermediate_ca_cert" {
  name         = "intermediate-ca-cert"
  value        = var.intermediate_ca_cert_pem
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  content_type = "application/x-pem-file"
  tags         = merge(var.tags, { cert-type = "intermediate-ca" })
}

# ─── AZURE JENKINS LEAF CERT (PFX) ────────────────────────────────────────────
resource "azurerm_key_vault_certificate" "jenkins_az_cert" {
  name         = "jenkins-az-cert"
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  tags         = merge(var.tags, { cert-type = "leaf" })

  certificate {
    contents = var.jenkins_az_cert_pfx_b64
    password = var.pfx_password
  }

  certificate_policy {
    issuer_parameters {
      name = "Unknown"
    }
    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = false
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
  }
}

# ─── AZURE JENKINS PRIVATE KEY (PEM) ──────────────────────────────────────────
resource "azurerm_key_vault_secret" "jenkins_az_key" {
  name         = "jenkins-az-key"
  value        = var.jenkins_az_key_pem
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  content_type = "application/x-pem-file"
  tags         = merge(var.tags, { cert-type = "leaf-key" })
}

# ─── AZURE JENKINS FULL CHAIN (PEM) ───────────────────────────────────────────
resource "azurerm_key_vault_secret" "jenkins_az_chain" {
  name         = "jenkins-az-chain"
  value        = var.jenkins_az_chain_pem
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  content_type = "application/x-pem-file"
  tags         = merge(var.tags, { cert-type = "leaf-chain" })
}

# ─── JENKINS VM MANAGED IDENTITY ACCESS ───────────────────────────────────────
resource "azurerm_key_vault_access_policy" "jenkins_vm_access" {
  count        = var.jenkins_vm_identity_principal_id != "" ? 1 : 0
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.jenkins_vm_identity_principal_id

  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
}
