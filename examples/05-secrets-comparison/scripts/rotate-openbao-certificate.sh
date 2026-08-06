#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIRECTORY=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIRECTORY}/lib.bash"

require_command bao
require_command jq
require_command openssl
require_command realpath
require_variable OPENBAO_CERTIFICATE_OUTPUT_DIR
require_openbao_transport
require_secure_output_directory "${OPENBAO_CERTIFICATE_OUTPUT_DIR}"
create_runtime_directory

REPOSITORY_ROOT=$(realpath "${SCRIPT_DIRECTORY}/../../..")
OUTPUT_ROOT=$(realpath "${OPENBAO_CERTIFICATE_OUTPUT_DIR}")
if [[ ${OUTPUT_ROOT}/ == "${REPOSITORY_ROOT}/"* ]]; then
  printf 'The certificate output directory must be outside the repository.\n' >&2
  exit 1
fi

PKI_MOUNT=${OPENBAO_PKI_MOUNT:-pki-lab}
PKI_ROLE=${OPENBAO_PKI_ROLE:-lab-internal}
COMMON_NAME=${OPENBAO_CERTIFICATE_COMMON_NAME:-comparison.lab.internal}
CERTIFICATE_TTL=${OPENBAO_CERTIFICATE_TTL:-1h}

VERSION_DIRECTORY=$(mktemp -d "${OPENBAO_CERTIFICATE_OUTPUT_DIR}/openbao-certificate.XXXXXX")
chmod 0700 "${VERSION_DIRECTORY}"
printf 'Certificate material directory: %s\n' "${VERSION_DIRECTORY}" >&2

PRIVATE_KEY="${VERSION_DIRECTORY}/private-key.pem"
CSR_FILE="${RUNTIME_DIRECTORY}/request.csr"
RESPONSE_FILE="${RUNTIME_DIRECTORY}/response.json"
CERTIFICATE_FILE="${RUNTIME_DIRECTORY}/certificate.pem"
CA_FILE="${RUNTIME_DIRECTORY}/ca.pem"

openssl req \
  -new \
  -newkey rsa:2048 \
  -nodes \
  -keyout "${PRIVATE_KEY}" \
  -out "${CSR_FILE}" \
  -subj "/CN=${COMMON_NAME}" \
  >/dev/null 2>&1

bao write \
  -format=json \
  "${PKI_MOUNT}/sign/${PKI_ROLE}" \
  csr=@"${CSR_FILE}" \
  common_name="${COMMON_NAME}" \
  ttl="${CERTIFICATE_TTL}" > "${RESPONSE_FILE}"

jq -er '.data.certificate' "${RESPONSE_FILE}" > "${CERTIFICATE_FILE}"
jq -er '.data.issuing_ca' "${RESPONSE_FILE}" > "${CA_FILE}"

SERIAL=$(openssl x509 -in "${CERTIFICATE_FILE}" -noout -serial)
EXPIRY=$(openssl x509 -in "${CERTIFICATE_FILE}" -noout -enddate)
FINGERPRINT=$(openssl x509 -in "${CERTIFICATE_FILE}" -noout -sha256 -fingerprint)
PUBLIC_KEY_HASH=$(openssl x509 -in "${CERTIFICATE_FILE}" -pubkey -noout \
  | openssl pkey -pubin -outform DER 2>/dev/null \
  | openssl dgst -sha256 -r \
  | cut -d' ' -f1)

install -m 0644 "${CERTIFICATE_FILE}" "${VERSION_DIRECTORY}/certificate.pem"
install -m 0644 "${CA_FILE}" "${VERSION_DIRECTORY}/ca.pem"

jq -n \
  --arg serial "${SERIAL#serial=}" \
  --arg expires "${EXPIRY#notAfter=}" \
  --arg fingerprint "${FINGERPRINT#sha256 Fingerprint=}" \
  --arg public_key_sha256 "${PUBLIC_KEY_HASH}" \
  --arg directory "${VERSION_DIRECTORY}" \
  '{serial:$serial,expires:$expires,fingerprint:$fingerprint,publicKeySha256:$public_key_sha256,directory:$directory}'
