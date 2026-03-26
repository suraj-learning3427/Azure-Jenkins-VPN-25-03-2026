variable "resource_group_name" {
  type    = string
  default = "azure-jenkins-core-infrastructure-rg"
}

variable "pfx_password" {
  type      = string
  sensitive = true
  default   = "pfx_password_change_me"
}

variable "jenkins_vm_identity_principal_id" {
  type        = string
  description = "Principal ID of the Jenkins VM managed identity"
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = { Environment = "production", Project = "jenkins", ManagedBy = "terraform" }
}

# Certificate content variables — populated by GitHub Actions via TFC workspace variables
variable "root_ca_cert_pem" {
  type        = string
  description = "Root CA certificate PEM content"
  sensitive   = true
  default     = ""
}

variable "intermediate_ca_cert_pem" {
  type        = string
  description = "Intermediate CA certificate PEM content"
  sensitive   = true
  default     = ""
}

variable "jenkins_az_cert_pfx_b64" {
  type        = string
  description = "Jenkins leaf certificate PFX content (base64 encoded)"
  sensitive   = true
  default     = ""
}

variable "jenkins_az_key_pem" {
  type        = string
  description = "Jenkins leaf certificate private key PEM content"
  sensitive   = true
  default     = ""
}

variable "jenkins_az_chain_pem" {
  type        = string
  description = "Jenkins leaf certificate full chain PEM content"
  sensitive   = true
  default     = ""
}
