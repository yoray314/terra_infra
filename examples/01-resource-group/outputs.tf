output "resource_group_id" {
  description = "Azure resource ID of the resource group."
  value       = azurerm_resource_group.example.id
}

output "resource_group_name" {
  description = "Name of the resource group."
  value       = azurerm_resource_group.example.name
}

output "resource_group_location" {
  description = "Azure region recorded on the resource group."
  value       = azurerm_resource_group.example.location
}
