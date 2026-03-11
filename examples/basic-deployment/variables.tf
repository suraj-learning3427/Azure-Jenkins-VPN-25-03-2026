# Variables for Basic Azure Firezone Gateway Deployment Example

variable "name_prefix" {
  type        = string
  default     = "example-"
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  default     = "East US"
  description = "Azure region for deployment"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Size of the virtual machines"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of gateway instances"
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
  description = "Admin username for VMs"
}

variable "ssh_public_key" {
  type        = string
  default     = ""
  description = "SSH public key (leave empty to generate)"
}

variable "enable_public_ip" {
  type        = bool
  default     = false
  description = "Enable public IP for instances (not needed with NAT Gateway)"
}

variable "enable_load_balancer" {
  type        = bool
  default     = false
  description = "Enable Application Gateway load balancer"
}

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Enable NAT Gateway for outbound connectivity"
}

# Firezone Configuration
variable "firezone_token" {
  type        = string
  description = "Firezone portal token"
  sensitive   = true
}

variable "firezone_api_url" {
  type        = string
  default     = "wss://api.firezone.dev"
  description = "Firezone API URL"
}

variable "firezone_version" {
  type        = string
  default     = "latest"
  description = "Firezone gateway version"
}

variable "log_level" {
  type        = string
  default     = "info"
  description = "Log level for Firezone gateway"
}

variable "log_format" {
  type        = string
  default     = "human"
  description = "Log format (human or json)"
}

variable "health_check" {
  type = object({
    port                = number
    path                = string
    interval_seconds    = number
    timeout_seconds     = number
    unhealthy_threshold = number
  })
  
  default = {
    port                = 8080
    path                = "/healthz"
    interval_seconds    = 15
    timeout_seconds     = 10
    unhealthy_threshold = 3
  }
  
  description = "Health check configuration"
}

variable "tags" {
  type        = map(string)
  default     = {
    Environment = "example"
    Project     = "firezone-gateway"
  }
  description = "Tags to apply to resources"
}