output "fqdn" {
  description = "Public DNS name restricted to the configured operator CIDR."
  value       = azurerm_public_ip.this.fqdn
}

output "url" {
  description = "HTTPS API address of the OpenBao node."
  value       = "https://${azurerm_public_ip.this.fqdn}:8200"
}

output "public_ip_address" {
  description = "Public IP address of the OpenBao VM."
  value       = azurerm_public_ip.this.ip_address
}

output "virtual_machine_name" {
  description = "Name of the OpenBao virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "virtual_network_id" {
  description = "Resource ID of the OpenBao virtual network."
  value       = azurerm_virtual_network.this.id
}

output "network_security_group_id" {
  description = "Resource ID of the OpenBao network security group."
  value       = azurerm_network_security_group.this.id
}
