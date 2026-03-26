# Variables for Multi-Region Firezone Gateway Deployment

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

# Primary Region Configuration
variable "primary_region" {
  type        = string
  default     = "East US"
  description = "Primary Azure region for Firezone deployment"
}

variable "primary_resource_group_name" {
  type        = string
  description = "Resource group name in primary region"
}

variable "primary_vnet_name" {
  type        = string
  description = "Virtual network name in primary region"
}

variable "primary_vnet_id" {
  type        = string
  description = "Virtual network ID in primary region"
}

variable "primary_subnet_name" {
  type        = string
  default     = "subnet-vpn"
  description = "Subnet name for Firezone in primary region"
}

# Secondary Region Configuration
variable "secondary_region" {
  type        = string
  default     = "West US 2"
  description = "Secondary Azure region for Firezone deployment"
}

variable "secondary_resource_group_name" {
  type        = string
  description = "Resource group name in secondary region"
}

variable "secondary_vnet_name" {
  type        = string
  description = "Virtual network name in secondary region"
}

variable "secondary_vnet_id" {
  type        = string
  description = "Virtual network ID in secondary region"
}

variable "secondary_subnet_name" {
  type        = string
  default     = "subnet-vpn"
  description = "Subnet name for Firezone in secondary region"
}

# VM Configuration
variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Size of the Firezone gateway VMs"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

# Firezone Configuration
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
  description = "Firezone portal token for gateway authentication"
  sensitive   = true
}

variable "firezone_token_secondary" {
  type        = string
  description = "Firezone portal token for secondary gateway authentication"
  sensitive   = true
}

variable "log_level" {
  type        = string
  default     = "info"
  description = "Log level for Firezone gateways"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}