data "azurerm_client_config" "current" {}

data "azurerm_storage_account" "state" {
  name                = var.state_storage_account_name
  resource_group_name = var.state_storage_resource_group_name
}

resource "azurerm_resource_group" "identity" {
  name     = var.identity_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "workload" {
  name     = var.workload_resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_container" "workload_state" {
  name                  = var.workload_state_container_name
  storage_account_id    = data.azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_user_assigned_identity" "plan" {
  name                = "id-github-plan"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = var.tags
}

resource "azurerm_user_assigned_identity" "apply" {
  name                = "id-github-apply"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "plan" {
  name                      = "github-plan"
  user_assigned_identity_id = azurerm_user_assigned_identity.plan.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.plan_subject
}

resource "azurerm_federated_identity_credential" "apply" {
  name                      = "github-apply"
  user_assigned_identity_id = azurerm_user_assigned_identity.apply.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.apply_subject

  lifecycle {
    precondition {
      condition     = var.environment_protection_confirmed
      error_message = "Confirm the protected lab environment and master branch policy before creating apply federation."
    }
  }
}

resource "azurerm_role_assignment" "plan_workload" {
  scope                = azurerm_resource_group.workload.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allow the GitHub plan identity to read the lab workload."
}

resource "azurerm_role_assignment" "plan_state" {
  scope                = azurerm_storage_container.workload_state.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.plan.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allow the GitHub plan identity to read workload state."
}

resource "azurerm_role_assignment" "apply_workload" {
  scope                = azurerm_resource_group.workload.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allow the protected GitHub environment to manage the lab workload."
}

resource "azurerm_role_assignment" "apply_state" {
  scope                = azurerm_storage_container.workload_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.apply.principal_id
  principal_type       = "ServicePrincipal"
  description          = "Allow the protected GitHub environment to lock and update workload state."
}
