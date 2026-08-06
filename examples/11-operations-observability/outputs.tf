output "resource_group_name" {
  description = "Name of the resource group containing observability resources."
  value       = azurerm_resource_group.monitoring.name
}

output "workspace_name" {
  description = "Name of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.monitoring.name
}

output "workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.monitoring.id
}

output "workspace_customer_id" {
  description = "Non-secret workspace identifier accepted by Azure CLI queries."
  value       = azurerm_log_analytics_workspace.monitoring.workspace_id
}

output "data_collection_rule_id" {
  description = "Resource ID of the OpenBao data collection rule."
  value       = azurerm_monitor_data_collection_rule.openbao.id
}

output "action_group_id" {
  description = "Resource ID of the operator action group."
  value       = azurerm_monitor_action_group.operators.id
}

output "alerts_enabled" {
  description = "Whether the saved queries and three alert rules are configured."
  value       = var.alerts_enabled
}

output "openbao_resource_group_name" {
  description = "Resource group containing the monitored OpenBao VM."
  value       = var.openbao_resource_group_name
}

output "openbao_virtual_machine_name" {
  description = "Name of the monitored OpenBao VM."
  value       = data.azurerm_virtual_machine.openbao.name
}

output "key_vault_resource_group_name" {
  description = "Resource group containing the monitored Key Vault."
  value       = var.key_vault_resource_group_name
}

output "key_vault_name" {
  description = "Name of the monitored Key Vault."
  value       = data.azurerm_key_vault.secrets.name
}
