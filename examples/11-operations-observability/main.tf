data "azurerm_virtual_machine" "openbao" {
  name                = var.openbao_virtual_machine_name
  resource_group_name = var.openbao_resource_group_name
}

data "azurerm_key_vault" "secrets" {
  name                = var.key_vault_name
  resource_group_name = var.key_vault_resource_group_name
}

resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = data.azurerm_virtual_machine.openbao.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "monitoring" {
  name                = var.workspace_name
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = var.daily_quota_gb

  allow_resource_only_permissions         = false
  immediate_data_purge_on_30_days_enabled = true
  internet_ingestion_access_type          = "Enabled"
  internet_query_access_type              = "Enabled"
  local_authentication_enabled            = false

  tags = var.tags
}

resource "azurerm_monitor_action_group" "operators" {
  name                = "ag-openbao-operators"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "openbao-ops"
  enabled             = true
  tags                = var.tags

  email_receiver {
    name                    = "primary-operator"
    email_address           = var.alert_email_address
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_data_collection_rule" "openbao" {
  name                = "dcr-openbao-lab"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  description         = "Collect bounded OpenBao host metrics, service logs, and security warnings."
  kind                = "Linux"
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "openbao-workspace"
      workspace_resource_id = azurerm_log_analytics_workspace.monitoring.id
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf", "Microsoft-Syslog"]
    destinations = ["openbao-workspace"]
  }

  data_sources {
    performance_counter {
      name                          = "openbao-host-performance"
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Logical Disk(*)\\% Free Space",
        "\\Memory\\Available MBytes Memory",
        "\\Processor(_Total)\\% Processor Time",
      ]
    }

    syslog {
      name           = "openbao-service-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["daemon"]
      log_levels     = ["Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
    }

    syslog {
      name           = "host-security-syslog"
      streams        = ["Microsoft-Syslog"]
      facility_names = ["auth", "authpriv", "syslog"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
    }
  }
}

resource "azurerm_virtual_machine_extension" "azure_monitor_agent" {
  name                        = "AzureMonitorLinuxAgent"
  virtual_machine_id          = data.azurerm_virtual_machine.openbao.id
  publisher                   = "Microsoft.Azure.Monitor"
  type                        = "AzureMonitorLinuxAgent"
  type_handler_version        = var.azure_monitor_agent_version
  auto_upgrade_minor_version  = true
  automatic_upgrade_enabled   = true
  failure_suppression_enabled = false
  tags                        = var.tags

  lifecycle {
    precondition {
      condition     = try(strcontains(data.azurerm_virtual_machine.openbao.identity[0].type, "SystemAssigned"), false)
      error_message = "Apply the Example 04 system-assigned identity before installing Azure Monitor Agent."
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "openbao" {
  name                    = "dcra-openbao-lab"
  target_resource_id      = data.azurerm_virtual_machine.openbao.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.openbao.id
  description             = "Send OpenBao VM host telemetry to the learning workspace."

  depends_on = [azurerm_virtual_machine_extension.azure_monitor_agent]
}

resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diagnostic-openbao-operations"
  target_resource_id         = data.azurerm_key_vault.secrets.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitoring.id

  enabled_log {
    category_group = "audit"
  }

}

resource "azurerm_log_analytics_saved_search" "openbao_host" {
  count = var.alerts_enabled ? 1 : 0

  name                       = "OpenBaoHostSignals"
  category                   = "OpenBao operations"
  display_name               = "OpenBao host heartbeat and errors"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitoring.id
  tags                       = var.tags

  query = <<-KQL
    Heartbeat
    | where _ResourceId =~ "${data.azurerm_virtual_machine.openbao.id}"
    | summarize LastHeartbeat=max(TimeGenerated), Samples=count() by Computer
    | join kind=fullouter (
        Syslog
        | where _ResourceId =~ "${data.azurerm_virtual_machine.openbao.id}"
        | where ProcessName in~ ("bao", "openbao")
        | summarize WarningEvents=countif(SyslogMessage contains "[WARN]" or SyslogMessage contains "[ERROR]") by Computer
      ) on Computer
  KQL
}

resource "azurerm_log_analytics_saved_search" "key_vault_audit" {
  count = var.alerts_enabled ? 1 : 0

  name                       = "KeyVaultAuditSummary"
  category                   = "OpenBao operations"
  display_name               = "Key Vault request and failure summary"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.monitoring.id
  tags                       = var.tags

  query = <<-KQL
    AzureDiagnostics
    | where _ResourceId =~ "${data.azurerm_key_vault.secrets.id}"
    | where ResourceProvider == "MICROSOFT.KEYVAULT" and Category == "AuditEvent"
    | where not(OperationName == "Authentication" and httpStatusCode_d == 401)
    | summarize Requests=count(), Failures=countif(httpStatusCode_d >= 400) by OperationName
    | order by Failures desc
  KQL
}

resource "azurerm_monitor_metric_alert" "high_cpu" {
  count = var.alerts_enabled ? 1 : 0

  name                = "alert-openbao-high-cpu"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [data.azurerm_virtual_machine.openbao.id]
  description         = "OpenBao VM average CPU exceeded the learning threshold for 15 minutes."
  enabled             = true
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.cpu_alert_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.operators.id
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "missing_heartbeat" {
  count = var.alerts_enabled ? 1 : 0

  name                    = "alert-openbao-missing-heartbeat"
  resource_group_name     = azurerm_resource_group.monitoring.name
  location                = azurerm_resource_group.monitoring.location
  scopes                  = [azurerm_log_analytics_workspace.monitoring.id]
  description             = "OpenBao VM sent no Azure Monitor Agent heartbeat during the previous 10 minutes."
  display_name            = "OpenBao heartbeat missing"
  enabled                 = true
  severity                = 1
  evaluation_frequency    = "PT5M"
  window_duration         = "PT10M"
  auto_mitigation_enabled = true
  tags                    = var.tags

  criteria {
    query = <<-KQL
      Heartbeat
      | where _ResourceId =~ "${data.azurerm_virtual_machine.openbao.id}"
    KQL

    operator                = "LessThan"
    threshold               = 1
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.operators.id]
  }

  depends_on = [azurerm_monitor_data_collection_rule_association.openbao]
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "openbao_warning" {
  count = var.alerts_enabled ? 1 : 0

  name                    = "alert-openbao-warning-syslog"
  resource_group_name     = azurerm_resource_group.monitoring.name
  location                = azurerm_resource_group.monitoring.location
  scopes                  = [azurerm_log_analytics_workspace.monitoring.id]
  description             = "OpenBao emitted a warning or error marker during the previous five minutes."
  display_name            = "OpenBao warning syslog"
  enabled                 = true
  severity                = 2
  evaluation_frequency    = "PT5M"
  window_duration         = "PT5M"
  auto_mitigation_enabled = true
  tags                    = var.tags

  criteria {
    query = <<-KQL
      Syslog
      | where _ResourceId =~ "${data.azurerm_virtual_machine.openbao.id}"
      | where ProcessName in~ ("bao", "openbao")
      | where SyslogMessage contains "[WARN]" or SyslogMessage contains "[ERROR]"
    KQL

    operator                = "GreaterThan"
    threshold               = 0
    time_aggregation_method = "Count"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.operators.id]
  }

  depends_on = [azurerm_monitor_data_collection_rule_association.openbao]
}
