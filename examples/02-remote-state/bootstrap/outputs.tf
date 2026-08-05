output "resource_group_name" {
  description = "Name of the resource group containing the backend."
  value       = azurerm_resource_group.state.name
}

output "storage_account_name" {
  description = "Name of the storage account containing state."
  value       = azurerm_storage_account.state.name
}

output "container_name" {
  description = "Name of the private state container."
  value       = azurerm_storage_container.state.name
}

output "state_key" {
  description = "Blob name used for the workload state."
  value       = var.state_key
}

output "backend_principal_object_id" {
  description = "Object ID granted access to the state container."
  value       = data.azurerm_client_config.current.object_id
}

output "backend_config" {
  description = "Non-sensitive partial backend configuration for the workload."
  value       = <<-EOT
    storage_account_name = ${jsonencode(azurerm_storage_account.state.name)}
    container_name       = ${jsonencode(azurerm_storage_container.state.name)}
    key                  = ${jsonencode(var.state_key)}
  EOT
}
