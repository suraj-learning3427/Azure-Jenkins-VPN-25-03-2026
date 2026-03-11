# Outputs for Azure Jenkins VM

output "jenkins_vm" {
  description = "Jenkins virtual machine information"
  value = {
    name                = azurerm_linux_virtual_machine.jenkins_vm.name
    id                  = azurerm_linux_virtual_machine.jenkins_vm.id
    private_ip_address  = azurerm_network_interface.jenkins_nic.private_ip_address
    size                = azurerm_linux_virtual_machine.jenkins_vm.size
  }
}

output "jenkins_identity" {
  description = "Jenkins user assigned identity information"
  value = {
    id           = azurerm_user_assigned_identity.jenkins_identity.id
    principal_id = azurerm_user_assigned_identity.jenkins_identity.principal_id
    client_id    = azurerm_user_assigned_identity.jenkins_identity.client_id
  }
}

output "data_disk" {
  description = "Jenkins data disk information"
  value = {
    name = azurerm_managed_disk.jenkins_data_disk.name
    id   = azurerm_managed_disk.jenkins_data_disk.id
    size = azurerm_managed_disk.jenkins_data_disk.disk_size_gb
  }
}

output "network_interface" {
  description = "Jenkins network interface information"
  value = {
    name               = azurerm_network_interface.jenkins_nic.name
    id                 = azurerm_network_interface.jenkins_nic.id
    private_ip_address = azurerm_network_interface.jenkins_nic.private_ip_address
  }
}

output "jenkins_access_info" {
  description = "Information for accessing Jenkins"
  value = {
    private_ip          = azurerm_network_interface.jenkins_nic.private_ip_address
    jenkins_port        = var.jenkins_port
    jenkins_url         = "http://${azurerm_network_interface.jenkins_nic.private_ip_address}:${var.jenkins_port}"
    admin_password_path = "/jenkins/jenkins_home/secrets/initialAdminPassword"
  }
}