#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIRECTORY}/lib.bash"

require_command bao
require_command jq
require_openbao_transport
create_runtime_directory

MOUNT_PATH=${OPENBAO_KV_MOUNT:-lab}
SECRET_PATH=${OPENBAO_SECRET_PATH:-comparison/token}
SECRET_FILE="${RUNTIME_DIRECTORY}/secret-value"

MOUNT_KEY="${MOUNT_PATH%/}/"
if ! bao secrets list -format=json \
  | jq -e --arg mount "${MOUNT_KEY}" \
    '.[$mount] | select(.type == "kv" and (.options.version | tostring) == "2")' \
    >/dev/null; then
  printf 'The requested OpenBao mount is not a KV v2 mount: %s\n' "${MOUNT_PATH}" >&2
  exit 1
fi

if [[ -n ${OPENBAO_EXPECTED_VERSION:-} ]]; then
  EXPECTED_VERSION=${OPENBAO_EXPECTED_VERSION}
else
  if ! METADATA=$(bao kv metadata get -format=json -mount="${MOUNT_PATH}" "${SECRET_PATH}"); then
    printf 'Unable to read metadata. Set OPENBAO_EXPECTED_VERSION=0 only for first creation.\n' >&2
    exit 1
  fi
  EXPECTED_VERSION=$(jq -er '.data.current_version' <<< "${METADATA}")
fi

if ! [[ ${EXPECTED_VERSION} =~ ^[0-9]+$ ]]; then
  printf 'Expected OpenBao version must be a non-negative integer.\n' >&2
  exit 1
fi

read_secret_file 'New OpenBao secret value: ' "${SECRET_FILE}"

VERSION=$(bao kv put \
  -format=json \
  -mount="${MOUNT_PATH}" \
  -cas="${EXPECTED_VERSION}" \
  "${SECRET_PATH}" \
  value=- < "${SECRET_FILE}" | jq -er '.data.version')

rm -f -- "${SECRET_FILE}"
printf '%s\n' "${VERSION}"
