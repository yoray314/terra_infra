resource "azurerm_policy_set_definition" "secret_platform" {
  name         = "secret-platform-production-guardrails-v1"
  policy_type  = "Custom"
  display_name = "Secret platform production guardrails"
  description  = "Resource-group guardrails for location, ownership, private access, vault recovery, and storage authentication."
  metadata     = local.policy_metadata

  parameters = jsonencode({
    allowedLocations = {
      type = "Array"
      metadata = {
        displayName = "Allowed locations"
        description = "Regions approved for secret-platform resources."
        strongType  = "location"
      }
    }
  })

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.allowed_locations.id
    reference_id         = "AllowedLocations"
    parameter_values = jsonencode({
      allowedLocations = {
        value = "[parameters('allowedLocations')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.required_tags.id
    reference_id         = "RequiredTags"
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.private_boundaries.id
    reference_id         = "PrivateBoundaries"
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.key_vault_resilience.id
    reference_id         = "KeyVaultResilience"
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.storage_authentication.id
    reference_id         = "StorageAuthentication"
  }
}

resource "azurerm_resource_group_policy_assignment" "secret_platform" {
  name                 = "secret-platform-guardrails"
  display_name         = "Secret platform production guardrails"
  description          = "Pilot in report-only mode, remediate findings, then explicitly enable deny enforcement."
  resource_group_id    = azurerm_resource_group.production.id
  policy_definition_id = azurerm_policy_set_definition.secret_platform.id
  enforce              = var.enforcement_enabled

  parameters = jsonencode({
    allowedLocations = {
      value = sort(tolist(var.allowed_locations))
    }
  })

  non_compliance_message {
    policy_definition_reference_id = "AllowedLocations"
    content                        = "Deploy regional secret-platform resources only in an approved location."
  }

  non_compliance_message {
    policy_definition_reference_id = "RequiredTags"
    content                        = "Declare owner, environment, data-classification, and criticality tags."
  }

  non_compliance_message {
    policy_definition_reference_id = "PrivateBoundaries"
    content                        = "Remove public IP resources and attachments and disable public vault or storage network access."
  }

  non_compliance_message {
    policy_definition_reference_id = "KeyVaultResilience"
    content                        = "Enable Key Vault purge protection and Azure RBAC authorization."
  }

  non_compliance_message {
    policy_definition_reference_id = "StorageAuthentication"
    content                        = "Require HTTPS, TLS 1.2, Entra authentication, and private blob data."
  }
}
