output "plan_client_id" {
  description = "Client ID configured as AZURE_PLAN_CLIENT_ID in GitHub."
  value       = azurerm_user_assigned_identity.plan.client_id
}

output "apply_client_id" {
  description = "Client ID configured as AZURE_APPLY_CLIENT_ID in GitHub."
  value       = azurerm_user_assigned_identity.apply.client_id
}

output "tenant_id" {
  description = "Tenant ID configured as AZURE_TENANT_ID in GitHub."
  value       = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  description = "Subscription ID configured as AZURE_SUBSCRIPTION_ID in GitHub."
  value       = data.azurerm_client_config.current.subscription_id
}

output "state_storage_account_name" {
  description = "Storage account configured as AZURE_STATE_STORAGE_ACCOUNT in GitHub."
  value       = data.azurerm_storage_account.state.name
}

output "state_container_name" {
  description = "Container configured as AZURE_STATE_CONTAINER in GitHub."
  value       = azurerm_storage_container.workload_state.name
}

output "workload_resource_group_name" {
  description = "Resource group managed by the GitHub apply identity."
  value       = azurerm_resource_group.workload.name
}
