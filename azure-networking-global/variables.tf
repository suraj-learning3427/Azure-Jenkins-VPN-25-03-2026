# Variables for Azure Networking Global (Hub)

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
}

variable "hub_address_space" {
  type        = string
  default     = "172.16.0.0/16"
  description = "Address space for the hub virtual network (equivalent to GCP vpc-hub)"
}

variable "vpn_subnet_cidr" {
  type        = string
  default     = "172.16.0.0/24"
  description = "CIDR block for VPN subnet (equivalent to GCP subnet-vpn)"
}

variable "gateway_subnet_cidr" {
  type        = string
  default     = "172.16.1.0/24"
  description = "CIDR block for VPN Gateway subnet (required by Azure)"
}

variable "bastion_subnet_cidr" {
  type        = string
  default     = "172.16.2.0/24"
  description = "CIDR block for Azure Bastion subnet (equivalent to IAP access)"
}

variable "spoke_address_spaces" {
  type        = list(string)
  default     = ["192.168.0.0/16"]
  description = "Address spaces of spoke networks for security rules"
}

variable "enable_vpn_gateway" {
  type        = bool
  default     = false
  description = "Whether to create VPN Gateway (equivalent to Firezone gateway)"
}

variable "vpn_gateway_sku" {
  type        = string
  default     = "VpnGw1"
  description = "SKU for VPN Gateway (VpnGw1, VpnGw2, VpnGw3)"
  
  validation {
    condition     = contains(["VpnGw1", "VpnGw2", "VpnGw3", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ"], var.vpn_gateway_sku)
    error_message = "VPN Gateway SKU must be one of: VpnGw1, VpnGw2, VpnGw3, VpnGw1AZ, VpnGw2AZ, VpnGw3AZ."
  }
}

variable "enable_bastion" {
  type        = bool
  default     = false
  description = "Whether to create Azure Bastion for secure access (equivalent to IAP)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}