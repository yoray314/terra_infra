provider "azurerm" {
  resource_provider_registrations = "none"
  use_cli                         = true

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = false
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
