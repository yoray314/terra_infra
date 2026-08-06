#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIRECTORY}/lib.bash"

require_command az
require_variable KEY_VAULT_NAME
create_runtime_directory

SECRET_NAME=${KEY_VAULT_SECRET_NAME:-comparison-token}
SECRET_FILE="${RUNTIME_DIRECTORY}/secret-value"

read_secret_file 'New Key Vault secret value: ' "${SECRET_FILE}"

SECRET_ID=$(az keyvault secret set \
  --vault-name "${KEY_VAULT_NAME}" \
  --name "${SECRET_NAME}" \
  --file "${SECRET_FILE}" \
  --encoding utf-8 \
  --content-type "opaque comparison token" \
  --query id \
  --output tsv \
  --only-show-errors)

rm -f -- "${SECRET_FILE}"
printf '%s\n' "${SECRET_ID}"
