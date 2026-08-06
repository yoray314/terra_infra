resource "azurerm_policy_definition" "allowed_locations" {
  name         = "secret-platform-allowed-locations-v1"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Secret platform resources use approved regions"
  description  = "Deny regional resources outside the approved production locations."
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

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          not = local.key_vault_recovery_request
        },
        {
          allOf = [
            {
              field = "location"
              notIn = "[parameters('allowedLocations')]"
            },
            {
              field     = "location"
              notEquals = "global"
            },
          ]
        },
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "required_tags" {
  name         = "secret-platform-required-tags-v1"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Secret platform resources declare ownership and data context"
  description  = "Deny taggable resources missing owner, environment, classification, or criticality."
  metadata     = local.policy_metadata

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          not = local.key_vault_recovery_request
        },
        {
          anyOf = [
            for tag_name in keys(local.required_tags) : {
              field  = "tags['${tag_name}']"
              exists = "false"
            }
          ]
        },
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "private_boundaries" {
  name         = "secret-platform-private-boundaries-v1"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Secret platform resources avoid public endpoints"
  description  = "Deny public IP resources and attachments, plus public network access on vaults and storage accounts."
  metadata     = local.policy_metadata

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          not = local.key_vault_recovery_request
        },
        {
          anyOf = [
            {
              field  = "type"
              equals = "Microsoft.Network/publicIPAddresses"
            },
            {
              field  = "type"
              equals = "Microsoft.Network/publicIPPrefixes"
            },
            {
              count = {
                field = "Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIPAddress"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/loadBalancers/frontendIPConfigurations[*].publicIPAddress.id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/applicationGateways/frontendIPConfigurations[*].publicIPAddress.id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/natGateways/publicIpAddresses[*].id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/natGateways/publicIpPrefixes[*].id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/azureFirewalls/ipConfigurations[*].publicIPAddress.id"
              }
              greater = 0
            },
            {
              field  = "Microsoft.Network/azureFirewalls/managementIpConfiguration.publicIPAddress.id"
              exists = "true"
            },
            {
              count = {
                field = "Microsoft.Network/bastionHosts/ipConfigurations[*].publicIPAddress.id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Network/virtualNetworkGateways/ipConfigurations[*].publicIPAddress.id"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Compute/virtualMachineScaleSets/virtualMachineProfile.networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Compute/virtualMachineScaleSets/virtualMachines/networkProfileConfiguration.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration"
              }
              greater = 0
            },
            {
              count = {
                field = "Microsoft.Compute/virtualMachineScaleSets/virtualmachines/networkProfile.networkInterfaceConfigurations[*].ipConfigurations[*].publicIPAddressConfiguration"
              }
              greater = 0
            },
            {
              allOf = [
                {
                  field  = "type"
                  equals = "Microsoft.KeyVault/vaults"
                },
                {
                  field     = "Microsoft.KeyVault/vaults/publicNetworkAccess"
                  notEquals = "Disabled"
                },
              ]
            },
            {
              allOf = [
                {
                  field  = "type"
                  equals = "Microsoft.Storage/storageAccounts"
                },
                {
                  field     = "Microsoft.Storage/storageAccounts/publicNetworkAccess"
                  notEquals = "Disabled"
                },
              ]
            },
          ]
        },
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "key_vault_resilience" {
  name         = "secret-platform-key-vault-resilience-v1"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Secret platform vaults retain recovery and Azure RBAC"
  description  = "Deny Key Vault resources without purge protection and Azure RBAC authorization."
  metadata     = local.policy_metadata

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.KeyVault/vaults"
        },
        {
          field     = "Microsoft.KeyVault/vaults/createMode"
          notEquals = "recover"
        },
        {
          anyOf = [
            {
              field     = "Microsoft.KeyVault/vaults/enablePurgeProtection"
              notEquals = true
            },
            {
              field     = "Microsoft.KeyVault/vaults/enableRbacAuthorization"
              notEquals = true
            },
          ]
        },
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

resource "azurerm_policy_definition" "storage_authentication" {
  name         = "secret-platform-storage-authentication-v1"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Secret platform storage disables weak access paths"
  description  = "Deny storage accounts that permit Shared Key, blob public access, non-HTTPS, or TLS below 1.2."
  metadata     = local.policy_metadata

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Storage/storageAccounts"
        },
        {
          anyOf = [
            {
              field     = "Microsoft.Storage/storageAccounts/allowSharedKeyAccess"
              notEquals = false
            },
            {
              field     = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess"
              notEquals = false
            },
            {
              field     = "Microsoft.Storage/storageAccounts/supportsHttpsTrafficOnly"
              notEquals = true
            },
            {
              field     = "Microsoft.Storage/storageAccounts/minimumTlsVersion"
              notEquals = "TLS1_2"
            },
          ]
        },
      ]
    }
    then = {
      effect = "deny"
    }
  })
}
