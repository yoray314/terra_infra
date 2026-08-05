data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "state" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_storage_account" "state" {
  name                = var.storage_account_name
  resource_group_name = azurerm_resource_group.state.name
  location            = azurerm_resource_group.state.location

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled      = true
  local_user_enabled              = false
  min_tls_version                 = "TLS1_2"
  public_network_access_enabled   = true
  shared_access_key_enabled       = false

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days                     = var.retention_days
      permanent_delete_enabled = false
    }

    container_delete_retention_policy {
      days = var.retention_days
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "state" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "state" {
  scope                = azurerm_storage_container.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  description          = "Allow the bootstrap caller to manage OpenTofu state blobs."
}
