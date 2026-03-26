# Azure Jenkins Infrastructure - Root Variables

variable "name_prefix" {
  type        = string
  default     = "azure-jenkins-"
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  default     = "East US"
  description = "Azure region for deployment"
}

variable "hub_address_space" {
  type        = string
  default     = "172.16.0.0/16"
  description = "Address space for the hub virtual network"
}

variable "spoke_address_space" {
  type        = string
  default     = "192.168.0.0/16"
  description = "Address space for the spoke virtual network"
}

variable "enable_bastion" {
  type        = bool
  default     = false
  description = "Whether to create Azure Bastion for secure access"
}

variable "enable_vpn_gateway" {
  type        = bool
  default     = false
  description = "Whether to create VPN Gateway"
}

variable "enable_hub_peering" {
  type        = bool
  default     = true
  description = "Whether to create VNet peering between hub and spoke"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "jenkins_vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Size of the Jenkins VM"
}

variable "jenkins_static_ip" {
  type        = string
  default     = "192.168.129.50"
  description = "Static private IP for Application Gateway"
}

variable "secondary_region" {
  type        = string
  default     = "West US 2"
  description = "Secondary Azure region for multi-region deployment"
}

variable "secondary_spoke_address_space" {
  type        = string
  default     = "10.168.0.0/16"
  description = "Address space for the secondary spoke virtual network"
}

variable "vpn_subnet_cidr" {
  type        = string
  default     = "192.168.130.0/24"
  description = "CIDR block for VPN subnet in primary region"
}

variable "secondary_vpn_subnet_cidr" {
  type        = string
  default     = "10.168.130.0/24"
  description = "CIDR block for VPN subnet in secondary region"
}

variable "secondary_jenkins_subnet_cidr" {
  type        = string
  default     = "10.168.0.0/24"
  description = "CIDR block for Jenkins subnet in secondary region"
}

variable "jenkins_fqdn" {
  type        = string
  default     = "jenkins-az.learningmyway.space"
  description = "FQDN for Jenkins"
}

variable "firezone_id" {
  type        = string
  description = "Firezone gateway ID for primary gateway"
  sensitive   = true
}

variable "firezone_id_secondary" {
  type        = string
  description = "Firezone gateway ID for secondary gateway"
  sensitive   = true
}

variable "firezone_token" {
  type        = string
  description = "Firezone authentication token for primary gateway registration"
  sensitive   = true
}

variable "firezone_token_secondary" {
  type        = string
  description = "Firezone authentication token for secondary gateway registration"
  sensitive   = true
}

variable "enable_firezone_multi_region" {
  type        = bool
  default     = true
  description = "Whether to enable multi-region Firezone deployment with load balancer"
}

variable "dns_zone_name" {
  type        = string
  default     = "learningmyway.space"
  description = "Private DNS zone name for Jenkins internal resolution"
}

variable "firezone_client_cidr" {
  type        = string
  default     = "100.64.0.0/10"
  description = "CIDR range assigned to Firezone VPN clients"
}

variable "pfx_password" {
  type        = string
  description = "Password for the Jenkins PFX certificate"
  sensitive   = true
  default     = "changeit"
}

# Certificate content — injected by GitHub Actions via TFC workspace variables
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
  description = "Jenkins leaf certificate PFX base64 encoded"
  sensitive   = true
  default     = ""
}

variable "jenkins_az_key_pem" {
  type        = string
  description = "Jenkins leaf certificate private key PEM"
  sensitive   = true
  default     = ""
}

variable "jenkins_az_chain_pem" {
  type        = string
  description = "Jenkins leaf certificate full chain PEM"
  sensitive   = true
  default     = ""
}

variable "tags" {
  type        = map(string)
  default     = {
    Environment = "production"
    Project     = "jenkins"
    ManagedBy   = "terraform"
  }
  description = "Tags to apply to all resources"
}