output "resource_group_name" {
  description = "Name of the private-networking resource group."
  value       = azurerm_resource_group.private_networking.name
}

output "key_vault_private_ip_address" {
  description = "Private IP assigned to the Key Vault private endpoint."
  value       = azurerm_private_endpoint.key_vault.private_service_connection[0].private_ip_address
}

output "key_vault_name" {
  description = "Name of the privately connected Key Vault."
  value       = data.azurerm_key_vault.secrets.name
}

output "private_dns_zone_name" {
  description = "Private DNS zone used by the Key Vault endpoint."
  value       = azurerm_private_dns_zone.key_vault.name
}
