# Azure Jenkins Application Gateway - Equivalent to GCP jenkins-ilb
# Creates internal HTTPS load balancer for Jenkins

# Data sources
data "azurerm_client_config" "current" {}

# Data source to reference existing resource group
data "azurerm_resource_group" "core_infrastructure" {
  name = var.resource_group_name
}

# Data source to reference existing virtual network
data "azurerm_virtual_network" "vpc_spoke" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

# Data source to reference existing Application Gateway subnet
data "azurerm_subnet" "subnet_appgw" {
  name                 = var.appgw_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

# Data source to reference existing Jenkins subnet
data "azurerm_subnet" "subnet_jenkins" {
  name                 = var.jenkins_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

# Static internal IP for Application Gateway (equivalent to GCP reserved IP)
resource "azurerm_public_ip" "appgw_pip" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "${var.name_prefix}jenkins-appgw-pip"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Self-signed certificate for HTTPS (equivalent to GCP SSL certificate)
resource "azurerm_key_vault" "jenkins_kv" {
  name                = "${var.name_prefix}jenkins-kv-${random_string.kv_suffix.result}"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Create",
      "Delete",
      "Get",
      "Import",
      "List",
      "Update",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]
  }
}

resource "random_string" "kv_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Self-signed certificate
resource "azurerm_key_vault_certificate" "jenkins_cert" {
  name         = "jenkins-ssl-cert"
  key_vault_id = azurerm_key_vault.jenkins_kv.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      extended_key_usage = ["1.3.6.1.5.5.7.3.1"]

      key_usage = [
        "cRLSign",
        "dataEncipherment",
        "digitalSignature",
        "keyAgreement",
        "keyCertSign",
        "keyEncipherment",
      ]

      subject            = "CN=${var.jenkins_fqdn}"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = [var.jenkins_fqdn]
      }
    }
  }
}

# User Assigned Identity for Application Gateway
resource "azurerm_user_assigned_identity" "appgw_identity" {
  name                = "${var.name_prefix}appgw-identity"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  tags                = var.tags
}

# Grant Application Gateway identity access to Key Vault
resource "azurerm_key_vault_access_policy" "appgw_kv_access" {
  key_vault_id = azurerm_key_vault.jenkins_kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.appgw_identity.principal_id

  certificate_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]
}

# Application Gateway (equivalent to GCP Internal HTTPS Load Balancer)
resource "azurerm_application_gateway" "jenkins_appgw" {
  name                = "${var.name_prefix}jenkins-appgw"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  tags                = var.tags

  sku {
    name     = var.appgw_sku_name
    tier     = var.appgw_sku_tier
    capacity = var.appgw_capacity
  }

  # User assigned identity for Key Vault access
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.appgw_identity.id]
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = data.azurerm_subnet.subnet_appgw.id
  }

  # Frontend IP configuration
  dynamic "frontend_ip_configuration" {
    for_each = var.enable_public_ip ? [1] : []
    content {
      name                 = "public-frontend-ip"
      public_ip_address_id = azurerm_public_ip.appgw_pip[0].id
    }
  }

  frontend_ip_configuration {
    name                          = "private-frontend-ip"
    subnet_id                     = data.azurerm_subnet.subnet_appgw.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.static_private_ip
  }

  # Frontend ports
  frontend_port {
    name = "https-port"
    port = 443
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # Backend address pool
  backend_address_pool {
    name         = "jenkins-backend-pool"
    ip_addresses = [var.jenkins_private_ip]
  }

  # Backend HTTP settings
  backend_http_settings {
    name                  = "jenkins-backend-http-settings"
    cookie_based_affinity = "Disabled"
    port                  = var.jenkins_port
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = "jenkins-health-probe"
  }

  # Health probe (equivalent to GCP health check)
  probe {
    name                = "jenkins-health-probe"
    protocol            = "Http"
    path                = var.health_check_path
    host                = var.jenkins_private_ip
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    unhealthy_threshold = var.health_check_unhealthy_threshold

    match {
      status_code = ["200-399"]
    }
  }

  # SSL certificate from Key Vault
  ssl_certificate {
    name                = "jenkins-ssl-cert"
    key_vault_secret_id = azurerm_key_vault_certificate.jenkins_cert.secret_id
  }

  # HTTPS listener
  http_listener {
    name                           = "jenkins-https-listener"
    frontend_ip_configuration_name = "private-frontend-ip"
    frontend_port_name             = "https-port"
    protocol                       = "Https"
    ssl_certificate_name           = "jenkins-ssl-cert"
  }

  # HTTP listener (redirect to HTTPS)
  http_listener {
    name                           = "jenkins-http-listener"
    frontend_ip_configuration_name = "private-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # Request routing rule for HTTPS
  request_routing_rule {
    name                       = "jenkins-https-routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "jenkins-https-listener"
    backend_address_pool_name  = "jenkins-backend-pool"
    backend_http_settings_name = "jenkins-backend-http-settings"
    priority                   = 100
  }

  # Request routing rule for HTTP (redirect to HTTPS)
  request_routing_rule {
    name               = "jenkins-http-redirect-rule"
    rule_type          = "Basic"
    http_listener_name = "jenkins-http-listener"
    redirect_configuration_name = "jenkins-https-redirect"
    priority           = 200
  }

  # Redirect configuration
  redirect_configuration {
    name                 = "jenkins-https-redirect"
    redirect_type        = "Permanent"
    target_listener_name = "jenkins-https-listener"
    include_path         = true
    include_query_string = true
  }

  depends_on = [
    azurerm_key_vault_access_policy.appgw_kv_access,
    azurerm_key_vault_certificate.jenkins_cert
  ]
}