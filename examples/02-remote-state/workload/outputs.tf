output "resource_group_id" {
  description = "Azure resource ID of the remotely tracked resource group."
  value       = azurerm_resource_group.workload.id
}

output "resource_group_name" {
  description = "Name of the remotely tracked resource group."
  value       = azurerm_resource_group.workload.name
}
