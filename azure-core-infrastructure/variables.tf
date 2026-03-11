# Variables for Azure Core Infrastructure (Spoke)

variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for all resource names"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
}

variable "spoke_address_space" {
  type        = string
  default     = "192.168.0.0/16"
  description = "Address space for the spoke virtual network (equivalent to GCP vpc-spoke)"
}

variable "jenkins_subnet_cidr" {
  type        = string
  default     = "192.168.0.0/24"
  description = "CIDR block for Jenkins subnet (equivalent to GCP subnet-jenkins)"
}

variable "appgw_subnet_cidr" {
  type        = string
  default     = "192.168.128.0/23"
  description = "CIDR block for Application Gateway subnet (equivalent to GCP proxy-only-subnet)"
}

variable "vpn_subnet_cidr" {
  type        = string
  default     = "192.168.130.0/24"
  description = "CIDR block for VPN subnet for Firezone gateway"
}

variable "hub_address_space" {
  type        = string
  default     = "172.16.0.0/16"
  description = "Address space of the hub network for security rules"
}

variable "enable_hub_peering" {
  type        = bool
  default     = true
  description = "Whether to create VNet peering to hub network"
}

variable "hub_vnet_id" {
  type        = string
  default     = ""
  description = "Resource ID of the hub virtual network for peering"
}

variable "hub_resource_group_name" {
  type        = string
  default     = ""
  description = "Resource group name of the hub virtual network"
}

variable "hub_vnet_name" {
  type        = string
  default     = ""
  description = "Name of the hub virtual network"
}

variable "hub_has_gateway" {
  type        = bool
  default     = false
  description = "Whether the hub network has a VPN gateway"
}

variable "use_remote_gateways" {
  type        = bool
  default     = false
  description = "Whether to use remote gateways in hub network"
}

variable "dns_zone_name" {
  type        = string
  default     = "dglearn.online"
  description = "Name of the private DNS zone (equivalent to GCP private DNS zone)"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags to apply to all resources"
}