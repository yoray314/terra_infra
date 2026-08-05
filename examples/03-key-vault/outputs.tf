output "resource_group_name" {
  description = "Name of the resource group containing the Key Vault."
  value       = azurerm_resource_group.key_vault.name
}

output "key_vault_id" {
  description = "Azure resource ID of the Key Vault."
  value       = azurerm_key_vault.example.id
}

output "key_vault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.example.name
}

output "key_vault_uri" {
  description = "Data-plane URI of the Key Vault."
  value       = azurerm_key_vault.example.vault_uri
}

output "key_vault_location" {
  description = "Azure region containing the Key Vault."
  value       = azurerm_key_vault.example.location
}

output "caller_object_id" {
  description = "Object ID receiving the Key Vault data-plane roles."
  value       = data.azurerm_client_config.current.object_id
}
