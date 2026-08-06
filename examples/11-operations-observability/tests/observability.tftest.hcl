mock_provider "azurerm" {
  mock_data "azurerm_virtual_machine" {
    defaults = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-openbao/providers/Microsoft.Compute/virtualMachines/vm-openbao-lab"
      location = "eastus"
      identity = [{
        identity_ids = []
        principal_id = "11111111-1111-1111-1111-111111111111"
        tenant_id    = "22222222-2222-2222-2222-222222222222"
        type         = "SystemAssigned"
      }]
    }
  }

  mock_data "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-key-vault/providers/Microsoft.KeyVault/vaults/kv-openbao-unit"
    }
  }

  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-openbao-unit"
      workspace_id = "33333333-3333-3333-3333-333333333333"
    }
  }

  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-monitoring/providers/Microsoft.Insights/actionGroups/ag-openbao-operators"
    }
  }

  mock_resource "azurerm_monitor_data_collection_rule" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-monitoring/providers/Microsoft.Insights/dataCollectionRules/dcr-openbao-lab"
    }
  }
}

variables {
  resource_group_name = "rg-opentofu-monitoring"
  workspace_name      = "law-openbao-unit"
  key_vault_name      = "kv-openbao-unit"
  alert_email_address = "operator@example.com"
}

run "bounded_observability_plan" {
  command = plan

  plan_options {
    refresh = false
  }

  assert {
    condition = (
      azurerm_log_analytics_workspace.monitoring.retention_in_days == 30 &&
      azurerm_log_analytics_workspace.monitoring.daily_quota_gb == 0.5 &&
      !azurerm_log_analytics_workspace.monitoring.local_authentication_enabled &&
      azurerm_log_analytics_workspace.monitoring.internet_ingestion_access_type == "Enabled"
    )
    error_message = "The learning workspace must retain bounded ingestion and identity-only authentication."
  }

  assert {
    condition = (
      toset(azurerm_monitor_data_collection_rule.openbao.data_flow[0].streams) == toset(["Microsoft-Perf", "Microsoft-Syslog"]) &&
      azurerm_monitor_data_collection_rule.openbao.data_sources[0].performance_counter[0].sampling_frequency_in_seconds == 60 &&
      toset(azurerm_monitor_data_collection_rule.openbao.data_sources[0].performance_counter[0].counter_specifiers) == toset(["\\Logical Disk(*)\\% Free Space", "\\Memory\\Available MBytes Memory", "\\Processor(_Total)\\% Processor Time"]) &&
      toset(one([for source in azurerm_monitor_data_collection_rule.openbao.data_sources[0].syslog : source if source.name == "openbao-service-syslog"]).log_levels) == toset(["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]) &&
      toset(one([for source in azurerm_monitor_data_collection_rule.openbao.data_sources[0].syslog : source if source.name == "host-security-syslog"]).log_levels) == toset(["Warning", "Error", "Critical", "Alert", "Emergency"])
    )
    error_message = "The data collection rule must retain bounded Linux host, service, and security telemetry."
  }

  assert {
    condition = (
      azurerm_virtual_machine_extension.azure_monitor_agent.publisher == "Microsoft.Azure.Monitor" &&
      azurerm_virtual_machine_extension.azure_monitor_agent.type == "AzureMonitorLinuxAgent" &&
      azurerm_virtual_machine_extension.azure_monitor_agent.type_handler_version == "1.43" &&
      azurerm_virtual_machine_extension.azure_monitor_agent.automatic_upgrade_enabled &&
      azurerm_virtual_machine_extension.azure_monitor_agent.auto_upgrade_minor_version
    )
    error_message = "Azure Monitor Agent must use the supported baseline and automatic safe deployment updates."
  }

  assert {
    condition = (
      azurerm_monitor_data_collection_rule_association.openbao.target_resource_id == data.azurerm_virtual_machine.openbao.id &&
      azurerm_monitor_data_collection_rule_association.openbao.data_collection_rule_id == azurerm_monitor_data_collection_rule.openbao.id
    )
    error_message = "The OpenBao VM must remain associated with its data collection rule."
  }

  assert {
    condition = (
      azurerm_monitor_diagnostic_setting.key_vault.target_resource_id == data.azurerm_key_vault.secrets.id &&
      azurerm_monitor_diagnostic_setting.key_vault.log_analytics_workspace_id == azurerm_log_analytics_workspace.monitoring.id &&
      contains([for log in azurerm_monitor_diagnostic_setting.key_vault.enabled_log : log.category_group], "audit")
    )
    error_message = "Key Vault audit logs must route to the monitoring workspace."
  }

  assert {
    condition = (
      length(azurerm_monitor_metric_alert.high_cpu) == 0 &&
      length(azurerm_monitor_scheduled_query_rules_alert_v2.missing_heartbeat) == 0 &&
      length(azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning) == 0 &&
      length(azurerm_log_analytics_saved_search.openbao_host) == 0 &&
      length(azurerm_log_analytics_saved_search.key_vault_audit) == 0
    )
    error_message = "Alert resources must not exist until telemetry and routing are verified."
  }

  assert {
    condition = (
      azurerm_monitor_action_group.operators.email_receiver[0].email_address == "operator@example.com" &&
      azurerm_monitor_action_group.operators.email_receiver[0].use_common_alert_schema
    )
    error_message = "The operator action group must route the common alert schema to the configured email."
  }
}

run "enabled_alert_plan" {
  command = plan

  plan_options {
    refresh = false
  }

  variables {
    alerts_enabled = true
  }

  assert {
    condition = (
      length(azurerm_monitor_metric_alert.high_cpu) == 1 &&
      length(azurerm_monitor_scheduled_query_rules_alert_v2.missing_heartbeat) == 1 &&
      length(azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning) == 1 &&
      length(azurerm_log_analytics_saved_search.openbao_host) == 1 &&
      length(azurerm_log_analytics_saved_search.key_vault_audit) == 1 &&
      azurerm_monitor_metric_alert.high_cpu[0].enabled &&
      azurerm_monitor_scheduled_query_rules_alert_v2.missing_heartbeat[0].enabled &&
      azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning[0].enabled
    )
    error_message = "Verified telemetry must create three enabled alert rules."
  }

  assert {
    condition = (
      strcontains(azurerm_monitor_scheduled_query_rules_alert_v2.missing_heartbeat[0].criteria[0].query, data.azurerm_virtual_machine.openbao.id) &&
      strcontains(azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning[0].criteria[0].query, data.azurerm_virtual_machine.openbao.id) &&
      strcontains(azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning[0].criteria[0].query, "ProcessName in~ (\"bao\", \"openbao\")") &&
      strcontains(azurerm_monitor_scheduled_query_rules_alert_v2.openbao_warning[0].criteria[0].query, "[WARN]") &&
      strcontains(azurerm_log_analytics_saved_search.key_vault_audit[0].query, "AzureDiagnostics") &&
      strcontains(azurerm_log_analytics_saved_search.key_vault_audit[0].query, "OperationName == \"Authentication\"")
    )
    error_message = "Log alerts must filter telemetry to the intended VM and OpenBao process markers."
  }
}

run "reject_vm_without_system_identity" {
  command = plan

  plan_options {
    refresh = false
  }

  override_data {
    target = data.azurerm_virtual_machine.openbao
    values = {
      id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-opentofu-openbao/providers/Microsoft.Compute/virtualMachines/vm-openbao-lab"
      location = "eastus"
      identity = []
    }
  }

  expect_failures = [azurerm_virtual_machine_extension.azure_monitor_agent]
}
