output "resource_group_name" {
  description = "Name of the resource group containing the OpenBao lab."
  value       = azurerm_resource_group.openbao.name
}

output "openbao_fqdn" {
  description = "Public DNS name restricted to the configured operator CIDR."
  value       = azurerm_public_ip.openbao.fqdn
}

output "openbao_url" {
  description = "HTTPS API address of the OpenBao lab."
  value       = "https://${azurerm_public_ip.openbao.fqdn}:8200"
}

output "public_ip_address" {
  description = "Public IP address of the OpenBao lab VM."
  value       = azurerm_public_ip.openbao.ip_address
}

output "virtual_machine_name" {
  description = "Name of the OpenBao lab virtual machine."
  value       = azurerm_linux_virtual_machine.openbao.name
}

output "ssh_command" {
  description = "Command used to connect to the VM."
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.openbao.fqdn}"
}
