# Variables for Azure Jenkins Application Gateway

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

variable "appgw_subnet_name" {
  type        = string
  default     = "subnet-appgw"
  description = "Name of the Application Gateway subnet"
}

variable "jenkins_subnet_name" {
  type        = string
  default     = "subnet-jenkins"
  description = "Name of the Jenkins subnet"
}

variable "jenkins_private_ip" {
  type        = string
  description = "Private IP address of the Jenkins server"
}

variable "jenkins_port" {
  type        = number
  default     = 8080
  description = "Port where Jenkins is running"
}

variable "jenkins_fqdn" {
  type        = string
  default     = "jenkins.np.dglearn.online"
  description = "FQDN for Jenkins (used in SSL certificate)"
}

variable "static_private_ip" {
  type        = string
  default     = "192.168.129.50"
  description = "Static private IP for Application Gateway (equivalent to GCP reserved IP)"
}

variable "enable_public_ip" {
  type        = bool
  default     = false
  description = "Whether to create a public IP for the Application Gateway"
}

variable "appgw_sku_name" {
  type        = string
  default     = "Standard_v2"
  description = "SKU name for Application Gateway"
  
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_name)
    error_message = "Application Gateway SKU must be Standard_v2 or WAF_v2."
  }
}

variable "appgw_sku_tier" {
  type        = string
  default     = "Standard_v2"
  description = "SKU tier for Application Gateway"
  
  validation {
    condition     = contains(["Standard_v2", "WAF_v2"], var.appgw_sku_tier)
    error_message = "Application Gateway SKU tier must be Standard_v2 or WAF_v2."
  }
}

variable "appgw_capacity" {
  type        = number
  default     = 2
  description = "Capacity (instance count) for Application Gateway"
  
  validation {
    condition     = var.appgw_capacity >= 1 && var.appgw_capacity <= 125
    error_message = "Application Gateway capacity must be between 1 and 125."
  }
}

variable "health_check_path" {
  type        = string
  default     = "/login"
  description = "Health check path for Jenkins (equivalent to GCP health check)"
}

variable "health_check_interval" {
  type        = number
  default     = 30
  description = "Health check interval in seconds"
}

variable "health_check_timeout" {
  type        = number
  default     = 30
  description = "Health check timeout in seconds"
}

variable "health_check_unhealthy_threshold" {
  type        = number
  default     = 3
  description = "Number of failed health checks before marking unhealthy"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}