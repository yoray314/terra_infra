mock_provider "azurerm" {}

override_resource {
  target = azurerm_resource_group.production
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-secret-platform-production"
  }
}

override_resource {
  target = azurerm_policy_definition.allowed_locations
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/secret-platform-allowed-locations-v1"
  }
}

override_resource {
  target = azurerm_policy_definition.required_tags
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/secret-platform-required-tags-v1"
  }
}

override_resource {
  target = azurerm_policy_definition.private_boundaries
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/secret-platform-private-boundaries-v1"
  }
}

override_resource {
  target = azurerm_policy_definition.key_vault_resilience
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/secret-platform-key-vault-resilience-v1"
  }
}

override_resource {
  target = azurerm_policy_definition.storage_authentication
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policyDefinitions/secret-platform-storage-authentication-v1"
  }
}

override_resource {
  target = azurerm_policy_set_definition.secret_platform
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/policySetDefinitions/secret-platform-production-guardrails-v1"
  }
}

variables {
  resource_group_name = "rg-secret-platform-production"
  location            = "eastus"
  allowed_locations   = ["eastus"]
  owner               = "platform-security"
  environment         = "production"
  data_classification = "restricted"
  criticality         = "mission-critical"
}

run "report_only_guardrails" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition = (
      azurerm_resource_group.production.tags["owner"] == "platform-security" &&
      azurerm_resource_group.production.tags["environment"] == "production" &&
      azurerm_resource_group.production.tags["data-classification"] == "restricted" &&
      azurerm_resource_group.production.tags["criticality"] == "mission-critical"
    )
    error_message = "The landing-zone resource group must retain all required governance tags."
  }

  assert {
    condition = (
      azurerm_policy_definition.allowed_locations.mode == "Indexed" &&
      endswith(azurerm_policy_definition.allowed_locations.name, "-v1") &&
      jsondecode(azurerm_policy_definition.allowed_locations.policy_rule).if.allOf[1].allOf[0].notIn == "[parameters('allowedLocations')]" &&
      jsondecode(azurerm_policy_definition.allowed_locations.policy_rule).then.effect == "deny"
    )
    error_message = "The location policy must deny resources outside the initiative parameter."
  }

  assert {
    condition = toset([
      for condition in jsondecode(azurerm_policy_definition.required_tags.policy_rule).if.allOf[1].anyOf : condition.field
      ]) == toset([
      "tags['criticality']",
      "tags['data-classification']",
      "tags['environment']",
      "tags['owner']",
    ])
    error_message = "The tag policy must require ownership, environment, classification, and criticality."
  }

  assert {
    condition = (
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "Microsoft.Network/publicIPAddresses") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "networkInterfaces/ipConfigurations[*].publicIPAddress") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "loadBalancers/frontendIPConfigurations[*].publicIPAddress.id") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "applicationGateways/frontendIPConfigurations[*].publicIPAddress.id") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "natGateways/publicIpAddresses[*].id") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "virtualMachineScaleSets/virtualMachineProfile.networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "virtualMachineScaleSets/virtualMachines/networkProfileConfiguration.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "virtualMachineScaleSets/virtualmachines/networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "Microsoft.KeyVault/vaults/publicNetworkAccess") &&
      strcontains(azurerm_policy_definition.private_boundaries.policy_rule, "Microsoft.Storage/storageAccounts/publicNetworkAccess")
    )
    error_message = "The private-boundary policy must cover public IP, Key Vault, and Storage exposure."
  }

  assert {
    condition = alltrue([
      for rule in [
        azurerm_policy_definition.allowed_locations.policy_rule,
        azurerm_policy_definition.required_tags.policy_rule,
        azurerm_policy_definition.private_boundaries.policy_rule,
        azurerm_policy_definition.key_vault_resilience.policy_rule,
      ] : strcontains(rule, "Microsoft.KeyVault/vaults/createMode") && strcontains(rule, "recover")
    ])
    error_message = "Policies that inspect omitted recovery properties must allow Key Vault recovery requests."
  }

  assert {
    condition = (
      strcontains(azurerm_policy_definition.key_vault_resilience.policy_rule, "enablePurgeProtection") &&
      strcontains(azurerm_policy_definition.key_vault_resilience.policy_rule, "enableRbacAuthorization")
    )
    error_message = "The Key Vault policy must retain purge protection and Azure RBAC requirements."
  }

  assert {
    condition = (
      strcontains(azurerm_policy_definition.storage_authentication.policy_rule, "allowSharedKeyAccess") &&
      strcontains(azurerm_policy_definition.storage_authentication.policy_rule, "allowBlobPublicAccess") &&
      strcontains(azurerm_policy_definition.storage_authentication.policy_rule, "supportsHttpsTrafficOnly") &&
      strcontains(azurerm_policy_definition.storage_authentication.policy_rule, "minimumTlsVersion")
    )
    error_message = "The storage policy must reject weak authentication and transport settings."
  }

  assert {
    condition = toset([
      for reference in azurerm_policy_set_definition.secret_platform.policy_definition_reference : reference.reference_id
      ]) == toset([
      "AllowedLocations",
      "KeyVaultResilience",
      "PrivateBoundaries",
      "RequiredTags",
      "StorageAuthentication",
    ])
    error_message = "The initiative must contain all five production guardrails."
  }

  assert {
    condition = (
      azurerm_resource_group_policy_assignment.secret_platform.resource_group_id == azurerm_resource_group.production.id &&
      !azurerm_resource_group_policy_assignment.secret_platform.enforce &&
      jsondecode(azurerm_resource_group_policy_assignment.secret_platform.parameters).allowedLocations.value == ["eastus"]
    )
    error_message = "The first assignment must be resource-group scoped, parameterized, and report-only."
  }
}

run "enforced_guardrails" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    enforcement_enabled = true
  }

  assert {
    condition     = azurerm_resource_group_policy_assignment.secret_platform.enforce
    error_message = "The reviewed second phase must enable deny enforcement."
  }
}

run "reject_disallowed_landing_zone_location" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    allowed_locations = ["westus2"]
  }

  expect_failures = [azurerm_resource_group.production]
}
