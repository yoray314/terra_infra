#!/usr/bin/env bash
set -Eeuo pipefail

set +x

required_variables=(
  KEY_VAULT_NAME
  KEY_VAULT_RESOURCE_GROUP
  LOG_ANALYTICS_WORKSPACE_NAME
  MONITORING_RESOURCE_GROUP
  OPENBAO_RESOURCE_GROUP
  OPENBAO_VM_NAME
)

if ! command -v az >/dev/null 2>&1; then
  printf 'Required command not found: az\n' >&2
  exit 1
fi

for variable_name in "${required_variables[@]}"; do
  if [[ -z ${!variable_name:-} ]]; then
    printf 'Required environment variable is empty: %s\n' "${variable_name}" >&2
    exit 1
  fi
done

subscription_id=$(az account show --query id --output tsv)
vm_id=$(az vm show \
  --resource-group "${OPENBAO_RESOURCE_GROUP}" \
  --name "${OPENBAO_VM_NAME}" \
  --query id \
  --output tsv)
key_vault_id=$(az keyvault show \
  --resource-group "${KEY_VAULT_RESOURCE_GROUP}" \
  --name "${KEY_VAULT_NAME}" \
  --query id \
  --output tsv)
workspace_customer_id=$(az monitor log-analytics workspace show \
  --resource-group "${MONITORING_RESOURCE_GROUP}" \
  --workspace-name "${LOG_ANALYTICS_WORKSPACE_NAME}" \
  --query customerId \
  --output tsv)

for resource_id in "${vm_id}" "${key_vault_id}"; do
  if [[ ${resource_id} != /subscriptions/${subscription_id}/* ]]; then
    printf 'Resource resolved outside the active subscription: %s\n' "${resource_id}" >&2
    exit 1
  fi
done

extension_state=$(az vm extension show \
  --resource-group "${OPENBAO_RESOURCE_GROUP}" \
  --vm-name "${OPENBAO_VM_NAME}" \
  --name AzureMonitorLinuxAgent \
  --query provisioningState \
  --output tsv)
if [[ ${extension_state} != Succeeded ]]; then
  printf 'Azure Monitor Agent provisioning state is %s, expected Succeeded.\n' "${extension_state}" >&2
  exit 1
fi

association_count=$(az rest \
  --method get \
  --url "https://management.azure.com${vm_id}/providers/Microsoft.Insights/dataCollectionRuleAssociations?api-version=2023-03-11" \
  --query 'length(value[?properties.dataCollectionRuleId != null])' \
  --output tsv)
if [[ ! ${association_count} =~ ^[1-9][0-9]*$ ]]; then
  printf 'No data collection rule is associated with the OpenBao VM.\n' >&2
  exit 1
fi

heartbeat_query="Heartbeat
| where _ResourceId =~ '${vm_id}'
| where Category == 'Azure Monitor Agent'
| summarize Samples=count(), LastHeartbeat=max(TimeGenerated)"
heartbeat_samples=$(az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${heartbeat_query}" \
  --timespan PT30M \
  --query '[0].Samples' \
  --output tsv)
if [[ ! ${heartbeat_samples} =~ ^[1-9][0-9]*$ ]]; then
  printf 'No Azure Monitor Agent heartbeat was found in the previous 30 minutes.\n' >&2
  exit 1
fi

syslog_query="Syslog
| where _ResourceId =~ '${vm_id}'
| where ProcessName =~ 'openbao-observability-test'
| summarize Samples=count()"
syslog_samples=$(az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${syslog_query}" \
  --timespan PT30M \
  --query '[0].Samples' \
  --output tsv)
if [[ ! ${syslog_samples} =~ ^[1-9][0-9]*$ ]]; then
  printf 'The synthetic OpenBao syslog verification event was not found.\n' >&2
  exit 1
fi

performance_query="Perf
| where _ResourceId =~ '${vm_id}'
| where CounterName in ('% Free Space', 'Available MBytes Memory', '% Processor Time')
| summarize Samples=count(), Counters=dcount(CounterName)"
performance_samples=$(az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${performance_query}" \
  --timespan PT30M \
  --query '[0].Samples' \
  --output tsv)
performance_counters=$(az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${performance_query}" \
  --timespan PT30M \
  --query '[0].Counters' \
  --output tsv)
if [[ ! ${performance_samples} =~ ^[1-9][0-9]*$ || ${performance_counters} != 3 ]]; then
  printf 'Expected all three OpenBao host performance counters in the previous 30 minutes.\n' >&2
  exit 1
fi

key_vault_query="AzureDiagnostics
| where _ResourceId =~ '${key_vault_id}'
| where ResourceProvider == 'MICROSOFT.KEYVAULT' and Category == 'AuditEvent'
| where not(OperationName == 'Authentication' and httpStatusCode_d == 401)
| summarize Samples=count(), Failures=countif(httpStatusCode_d >= 400)"
key_vault_samples=$(az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${key_vault_query}" \
  --timespan PT30M \
  --query '[0].Samples' \
  --output tsv)
if [[ ! ${key_vault_samples} =~ ^[1-9][0-9]*$ ]]; then
  printf 'No Key Vault audit event was found in the previous 30 minutes.\n' >&2
  exit 1
fi

printf 'Azure Monitor Agent: %s\n' "${extension_state}"
printf 'Data collection rule associations: %s\n' "${association_count}"
printf 'Heartbeat samples in 30 minutes: %s\n' "${heartbeat_samples}"
printf 'Synthetic syslog samples in 30 minutes: %s\n' "${syslog_samples}"
printf 'Performance samples across three counters: %s\n' "${performance_samples}"
printf 'Key Vault audit samples in 30 minutes: %s\n' "${key_vault_samples}"

syslog_query="Syslog
| where _ResourceId =~ '${vm_id}'
| summarize Events=count() by SeverityLevel
| order by Events desc"
az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${syslog_query}" \
  --timespan PT24H \
  --output table

key_vault_query="AzureDiagnostics
| where _ResourceId =~ '${key_vault_id}'
| where ResourceProvider == 'MICROSOFT.KEYVAULT' and Category == 'AuditEvent'
| where not(OperationName == 'Authentication' and httpStatusCode_d == 401)
| summarize Requests=count(), Failures=countif(httpStatusCode_d >= 400) by OperationName
| order by Failures desc"
az monitor log-analytics query \
  --workspace "${workspace_customer_id}" \
  --analytics-query "${key_vault_query}" \
  --timespan PT24H \
  --output table
