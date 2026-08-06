locals {
  required_tags = {
    owner                 = var.owner
    environment           = var.environment
    "data-classification" = var.data_classification
    criticality           = var.criticality
  }

  tags = merge(var.tags, local.required_tags, {
    example      = "12-production-hardening"
    "managed-by" = "opentofu"
    state        = "azure-blob"
  })

  policy_metadata = jsonencode({
    category = "Secret platform guardrails"
    version  = "1.0.0"
  })

  key_vault_recovery_request = {
    allOf = [
      {
        field  = "type"
        equals = "Microsoft.KeyVault/vaults"
      },
      {
        field  = "Microsoft.KeyVault/vaults/createMode"
        equals = "recover"
      },
    ]
  }
}

resource "azurerm_resource_group" "production" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags

  lifecycle {
    precondition {
      condition     = contains(var.allowed_locations, var.location)
      error_message = "The landing-zone resource group location must be included in allowed_locations."
    }
  }
}
