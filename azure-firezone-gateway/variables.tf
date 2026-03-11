# Variables for Azure Firezone Gateway

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group"
}

variable "vnet_name" {
  type        = string
  description = "Name of the existing virtual network"
}

variable "subnet_name" {
  type        = string
  default     = "subnet-vpn"
  description = "Name of the existing subnet for Firezone gateway"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Size of the Firezone gateway VM"
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Admin username for the VM"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "enable_public_ip" {
  type        = bool
  default     = true
  description = "Whether to assign a public IP to the gateway"
}

variable "firezone_token" {
  type        = string
  description = "Firezone portal token for gateway authentication"
  sensitive   = true
}

variable "log_level" {
  type        = string
  default     = "info"
  description = "Log level for Firezone gateway (debug, info, warn, error)"
  
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