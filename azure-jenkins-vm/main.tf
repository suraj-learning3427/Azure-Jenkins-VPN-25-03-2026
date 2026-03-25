# Azure Jenkins VM - Equivalent to GCP jenkins-vm
# Creates Jenkins server on Azure VM

# Data sources
data "azurerm_client_config" "current" {}

# Data source to reference existing resource group
data "azurerm_resource_group" "core_infrastructure" {
  name = var.resource_group_name
}

# Data source to reference existing virtual network
data "azurerm_virtual_network" "vpc_spoke" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
}

# Data source to reference existing subnet
data "azurerm_subnet" "subnet_jenkins" {
  name                 = var.subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.resource_group_name
}

# User Assigned Identity for Jenkins VM
resource "azurerm_user_assigned_identity" "jenkins_identity" {
  name                = "${var.name_prefix}jenkins-identity"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  tags                = var.tags
}

# Data disk for Jenkins (equivalent to GCP persistent disk)
resource "azurerm_managed_disk" "jenkins_data_disk" {
  name                 = "${var.name_prefix}jenkins-data-disk"
  location             = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name  = data.azurerm_resource_group.core_infrastructure.name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  tags                 = var.tags
}

# Network Interface for Jenkins VM
resource "azurerm_network_interface" "jenkins_nic" {
  name                = "${var.name_prefix}jenkins-nic"
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet_jenkins.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Jenkins Virtual Machine
resource "azurerm_linux_virtual_machine" "jenkins_vm" {
  name                = var.vm_name
  location            = data.azurerm_resource_group.core_infrastructure.location
  resource_group_name = data.azurerm_resource_group.core_infrastructure.name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  # Disable password authentication
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.jenkins_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }

  # Ubuntu 22.04 LTS (Reliable and widely supported for Jenkins)
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # User assigned identity
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.jenkins_identity.id]
  }

  # Custom data for cloud-init (startup script)
  custom_data = base64encode(templatefile("${path.module}/templates/jenkins-startup.sh", {
    data_disk_device = "/dev/sdc"
    mount_point      = "/jenkins"
    jenkins_port     = var.jenkins_port
    kv_name          = var.kv_name
  }))

  depends_on = [
    azurerm_managed_disk.jenkins_data_disk,
    azurerm_user_assigned_identity.jenkins_identity
  ]
}

# Attach data disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "jenkins_data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.jenkins_data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.jenkins_vm.id
  lun                = "0"
  caching            = "ReadWrite"
}