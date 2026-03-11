# Variables for Azure Jenkins VM

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
  default     = "subnet-jenkins"
  description = "Name of the existing subnet for Jenkins"
}

variable "vm_name" {
  type        = string
  default     = "jenkins-server"
  description = "Name of the Jenkins virtual machine"
}

variable "vm_size" {
  type        = string
  default     = "Standard_D2s_v3"
  description = "Size of the Jenkins VM (equivalent to GCP e2-standard-2)"
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

variable "os_disk_type" {
  type        = string
  default     = "Premium_LRS"
  description = "Type of OS disk (Premium_LRS, Standard_LRS, StandardSSD_LRS)"
  
  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS"], var.os_disk_type)
    error_message = "OS disk type must be Premium_LRS, Standard_LRS, or StandardSSD_LRS."
  }
}

variable "os_disk_size_gb" {
  type        = number
  default     = 32
  description = "Size of the OS disk in GB (minimum 32 GB for Rocky Linux)"
}

variable "data_disk_type" {
  type        = string
  default     = "Premium_LRS"
  description = "Type of data disk for Jenkins data"
  
  validation {
    condition     = contains(["Premium_LRS", "Standard_LRS", "StandardSSD_LRS"], var.data_disk_type)
    error_message = "Data disk type must be Premium_LRS, Standard_LRS, or StandardSSD_LRS."
  }
}

variable "data_disk_size_gb" {
  type        = number
  default     = 20
  description = "Size of the data disk for Jenkins in GB"
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