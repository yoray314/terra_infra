#!/usr/bin/env bash
set -Eeuo pipefail

set +x

if ! command -v az >/dev/null 2>&1; then
  printf 'Required command not found: az\n' >&2
  exit 1
fi
if ! az extension show --name bastion --query name --output tsv >/dev/null 2>&1; then
  printf 'Required Azure CLI extension not found: bastion\n' >&2
  exit 1
fi

required_variables=(
  EXPECTED_ENFORCEMENT_MODE
  EXPECTED_SUBSCRIPTION_ID
  GUARDRAIL_RESOURCE_GROUP
  POLICY_ASSIGNMENT_NAME
)
for variable_name in "${required_variables[@]}"; do
  if [[ -z ${!variable_name:-} ]]; then
    printf 'Required environment variable is empty: %s\n' "${variable_name}" >&2
    exit 1
  fi
done

require_policy_data=${REQUIRE_POLICY_DATA:-false}
if [[ ${require_policy_data} != true && ${require_policy_data} != false ]]; then
  printf 'REQUIRE_POLICY_DATA accepts only true or false.\n' >&2
  exit 1
fi
if [[ ${EXPECTED_ENFORCEMENT_MODE} != Default && ${EXPECTED_ENFORCEMENT_MODE} != DoNotEnforce ]]; then
  printf 'EXPECTED_ENFORCEMENT_MODE must be Default or DoNotEnforce.\n' >&2
  exit 1
fi

active_subscription_id=$(az account show --query id --output tsv)
if [[ ${active_subscription_id} != "${EXPECTED_SUBSCRIPTION_ID}" ]]; then
  printf 'Active subscription %s does not match expected subscription %s.\n' \
    "${active_subscription_id}" "${EXPECTED_SUBSCRIPTION_ID}" >&2
  exit 1
fi

resource_group_id=$(az group show \
  --name "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query id \
  --output tsv)
if [[ ${resource_group_id} != /subscriptions/${EXPECTED_SUBSCRIPTION_ID}/* ]]; then
  printf 'The guardrail resource group is outside the expected subscription.\n' >&2
  exit 1
fi

enforcement_mode=$(az policy assignment show \
  --name "${POLICY_ASSIGNMENT_NAME}" \
  --scope "${resource_group_id}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query enforcementMode \
  --output tsv)
if [[ -z ${enforcement_mode} ]]; then
  enforcement_mode=Default
fi
if [[ ${enforcement_mode} != "${EXPECTED_ENFORCEMENT_MODE}" ]]; then
  printf 'Policy enforcement mode is %s, expected %s.\n' \
    "${enforcement_mode}" "${EXPECTED_ENFORCEMENT_MODE}" >&2
  exit 1
fi

public_ip_resource_count=$(az network public-ip list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query 'length(@)' \
  --output tsv)
public_ip_prefix_count=$(az network public-ip prefix list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query 'length(@)' \
  --output tsv)
public_nic_count=$(az network nic list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?ipConfigurations[?publicIPAddress != null]] | length(@)' \
  --output tsv)
public_load_balancer_count=$(az network lb list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?frontendIPConfigurations[?publicIPAddress != null]] | length(@)' \
  --output tsv)
public_application_gateway_count=$(az network application-gateway list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?frontendIPConfigurations[?publicIPAddress != null]] | length(@)' \
  --output tsv)
public_nat_gateway_count=$(az network nat gateway list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?publicIpAddresses[0] != null || publicIpPrefixes[0] != null] | length(@)' \
  --output tsv)
public_firewall_count=$(az network firewall list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?ipConfigurations[?publicIPAddress != null] || managementIpConfiguration.publicIPAddress != null] | length(@)' \
  --output tsv)
public_bastion_count=$(az network bastion list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?ipConfigurations[?publicIPAddress != null]] | length(@)' \
  --output tsv)
public_virtual_network_gateway_count=$(az network vnet-gateway list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?ipConfigurations[?publicIPAddress != null]] | length(@)' \
  --output tsv)
public_vmss_model_count=$(az vmss list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[?virtualMachineProfile.networkProfile.networkInterfaceConfigurations[?ipConfigurations[?publicIPAddressConfiguration != null]]] | length(@)' \
  --output tsv)
vmss_names=$(az vmss list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query '[].name' \
  --output tsv)
public_vmss_instance_count=0
if [[ -n ${vmss_names} ]]; then
  while IFS= read -r vmss_name; do
    instance_public_ip_count=$(az vmss list-instance-public-ips \
      --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
      --name "${vmss_name}" \
      --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
      --query 'length(@)' \
      --output tsv)
    public_vmss_instance_count=$((public_vmss_instance_count + instance_public_ip_count))
  done <<< "${vmss_names}"
fi
public_boundary_count=$((
  public_ip_resource_count +
  public_ip_prefix_count +
  public_nic_count +
  public_load_balancer_count +
  public_application_gateway_count +
  public_nat_gateway_count +
  public_firewall_count +
  public_bastion_count +
  public_virtual_network_gateway_count +
  public_vmss_model_count +
  public_vmss_instance_count
))
if [[ ${public_boundary_count} != 0 ]]; then
  printf 'Found %s public IP resource or attachment violation(s) in the private landing zone.\n' \
    "${public_boundary_count}" >&2
  exit 1
fi

weak_storage_count=$(az storage account list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query "[?publicNetworkAccess != 'Disabled' || allowSharedKeyAccess != \`false\` || allowBlobPublicAccess != \`false\` || enableHttpsTrafficOnly != \`true\` || minimumTlsVersion != 'TLS1_2'] | length(@)" \
  --output tsv)
if [[ ${weak_storage_count} != 0 ]]; then
  printf 'Found %s storage account(s) outside the authentication or network baseline.\n' \
    "${weak_storage_count}" >&2
  exit 1
fi

weak_vault_count=$(az keyvault list \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --resource-type vault \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query "[?properties.publicNetworkAccess != 'Disabled' || properties.enablePurgeProtection != \`true\` || properties.enableRbacAuthorization != \`true\`] | length(@)" \
  --output tsv)
if [[ ${weak_vault_count} != 0 ]]; then
  printf 'Found %s Key Vault resource(s) outside the private, purge-protected RBAC baseline.\n' \
    "${weak_vault_count}" >&2
  exit 1
fi

policy_assignment_results=$(az policy state summarize \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --policy-assignment "${POLICY_ASSIGNMENT_NAME}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query 'length(policyAssignments)' \
  --output tsv)
noncompliant_resources=$(az policy state summarize \
  --resource-group "${GUARDRAIL_RESOURCE_GROUP}" \
  --policy-assignment "${POLICY_ASSIGNMENT_NAME}" \
  --subscription "${EXPECTED_SUBSCRIPTION_ID}" \
  --query 'results.nonCompliantResources' \
  --output tsv)
if [[ -z ${policy_assignment_results} || ${policy_assignment_results} == 0 ]]; then
  if [[ ${require_policy_data} == true ]]; then
    printf 'No policy compliance result is available; trigger and await a scan before enforcement.\n' >&2
    exit 1
  fi
  policy_assignment_results=unavailable
  noncompliant_resources=unavailable
elif [[ ${noncompliant_resources} != 0 ]]; then
  printf 'Azure Policy reports %s noncompliant resource(s).\n' "${noncompliant_resources}" >&2
  exit 1
fi

printf 'Active subscription: %s\n' "${active_subscription_id}"
printf 'Assignment enforcement mode: %s\n' "${enforcement_mode}"
printf 'Public IP resources or attachments: %s\n' "${public_boundary_count}"
printf 'Storage baseline violations: %s\n' "${weak_storage_count}"
printf 'Key Vault baseline violations: %s\n' "${weak_vault_count}"
printf 'Policy assignment summaries: %s\n' "${policy_assignment_results}"
printf 'Policy noncompliant resources: %s\n' "${noncompliant_resources}"
