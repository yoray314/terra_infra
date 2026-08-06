#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIRECTORY}/lib.bash"

require_command az
require_variable KEY_VAULT_NAME

CERTIFICATE_NAME=${KEY_VAULT_CERTIFICATE_NAME:-comparison-certificate}
POLICY_FILE=${KEY_VAULT_CERTIFICATE_POLICY:-${SCRIPT_DIRECTORY}/../../03-key-vault/certificate-policy.json}

if [[ ! -f ${POLICY_FILE} ]]; then
  printf 'Certificate policy not found: %s\n' "${POLICY_FILE}" >&2
  exit 1
fi

az keyvault certificate create \
  --vault-name "${KEY_VAULT_NAME}" \
  --name "${CERTIFICATE_NAME}" \
  --policy "@${POLICY_FILE}" \
  --output none \
  --only-show-errors

az keyvault certificate show \
  --vault-name "${KEY_VAULT_NAME}" \
  --name "${CERTIFICATE_NAME}" \
  --query '{id:id,thumbprint:x509ThumbprintHex,enabled:attributes.enabled,expires:attributes.expires}' \
  --output json \
  --only-show-errors
