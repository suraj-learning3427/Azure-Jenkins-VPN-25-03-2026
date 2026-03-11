# Variables for Azure Core Infrastructure (Secondary Region)

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  description = "Azure region for secondary deployment"
}

variable "spoke_address_space" {
  type        = string
  default     = "10.168.0.0/16"
  description = "Address space for the secondary spoke virtual network"
}

variable "jenkins_subnet_cidr" {
  type        = string
  default     = "10.168.0.0/24"
  description = "CIDR block for Jenkins subnet in secondary region"
}

variable "vpn_subnet_cidr" {
  type        = string
  default     = "10.168.130.0/24"
  description = "CIDR block for VPN subnet for Firezone gateway in secondary region"
}

variable "jenkins_port" {
  type        = string
  default     = "8080"
  description = "Port for Jenkins web interface"
}

variable "enable_primary_peering" {
  type        = bool
  default     = true
  description = "Whether to create VNet peering to primary region"
}

variable "primary_vnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of the primary virtual network for peering"
}

variable "primary_resource_group_name" {
  type        = string
  default     = ""
  description = "Resource group name of the primary virtual network"
}

variable "primary_vnet_name" {
  type        = string
  default     = ""
  description = "Name of the primary virtual network"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}