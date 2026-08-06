provider "azurerm" {
  resource_provider_registrations = "none"
  use_cli                         = true

  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
