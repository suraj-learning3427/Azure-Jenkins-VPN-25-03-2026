# Variables for Multi-Region Jenkins Deployment

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

# Primary Region Configuration
variable "primary_region" {
  type        = string
  default     = "East US"
  description = "Primary Azure region for Jenkins deployment"
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
  default     = "subnet-jenkins"
  description = "Subnet name for Jenkins in primary region"
}

# Secondary Region Configuration
variable "secondary_region" {
  type        = string
  default     = "West US 2"
  description = "Secondary Azure region for Jenkins deployment"
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
  default     = "subnet-jenkins"
  description = "Subnet name for Jenkins in secondary region"
}

# VM Configuration
variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Size of the Jenkins VMs"
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for VM access"
}

variable "jenkins_port" {
  type        = number
  default     = 8080
  description = "Port for Jenkins web interface"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}