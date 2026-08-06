output "resource_group_name" {
  description = "Name of the resource group containing the OpenBao lab."
  value       = azurerm_resource_group.openbao.name
}

output "openbao_fqdn" {
  description = "Public DNS name restricted to the configured operator CIDR."
  value       = module.openbao.fqdn
}

output "openbao_url" {
  description = "HTTPS API address of the OpenBao lab."
  value       = module.openbao.url
}

output "public_ip_address" {
  description = "Public IP address of the OpenBao lab VM."
  value       = module.openbao.public_ip_address
}

output "virtual_machine_name" {
  description = "Name of the OpenBao lab virtual machine."
  value       = module.openbao.virtual_machine_name
}

output "ssh_command" {
  description = "Command used to connect to the VM."
  value       = "ssh ${var.admin_username}@${module.openbao.fqdn}"
}
