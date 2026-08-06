output "resource_group_name" {
  description = "Name of the protected landing-zone resource group."
  value       = azurerm_resource_group.production.name
}

output "resource_group_id" {
  description = "Resource ID of the protected landing-zone resource group."
  value       = azurerm_resource_group.production.id
}

output "policy_set_definition_id" {
  description = "Resource ID of the custom production guardrail initiative."
  value       = azurerm_policy_set_definition.secret_platform.id
}

output "policy_assignment_name" {
  description = "Name of the resource-group policy assignment."
  value       = azurerm_resource_group_policy_assignment.secret_platform.name
}

output "enforcement_enabled" {
  description = "Whether deny effects are enforced for new and updated resources."
  value       = var.enforcement_enabled
}

output "policy_definition_ids" {
  description = "Resource IDs of the custom definitions included in the initiative."
  value = {
    allowed_locations      = azurerm_policy_definition.allowed_locations.id
    key_vault_resilience   = azurerm_policy_definition.key_vault_resilience.id
    private_boundaries     = azurerm_policy_definition.private_boundaries.id
    required_tags          = azurerm_policy_definition.required_tags.id
    storage_authentication = azurerm_policy_definition.storage_authentication.id
  }
}
