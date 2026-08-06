data "azurerm_client_config" "current" {}

locals {
  data_plane_roles = toset([
    "Key Vault Certificates Officer",
    "Key Vault Secrets Officer",
  ])
}

resource "azurerm_resource_group" "key_vault" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_key_vault" "example" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.key_vault.location
  resource_group_name = azurerm_resource_group.key_vault.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true

  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false

  public_network_access_enabled = var.public_network_access_enabled
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7

  network_acls {
    bypass         = "None"
    default_action = "Deny"
    ip_rules       = var.allowed_ipv4_cidrs
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "data_plane" {
  for_each = local.data_plane_roles

  scope                = azurerm_key_vault.example.id
  role_definition_name = each.value
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "User"
  description          = "Allow the signed-in lab user to manage ${each.value} data."
}
