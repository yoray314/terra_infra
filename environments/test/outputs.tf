output "resource_group_name" {
  description = "Name of the test resource group."
  value       = azurerm_resource_group.this.name
}

output "openbao_url" {
  description = "HTTPS API address of the test OpenBao node."
  value       = module.openbao.url
}

output "openbao_fqdn" {
  description = "Public DNS name of the test OpenBao node."
  value       = module.openbao.fqdn
}

output "virtual_machine_name" {
  description = "Name of the test OpenBao VM."
  value       = module.openbao.virtual_machine_name
}

output "ssh_command" {
  description = "Command used to connect to the test VM."
  value       = "ssh ${var.admin_username}@${module.openbao.fqdn}"
}
