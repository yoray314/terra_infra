set -Eeuo pipefail

set +x

require_command() {
  local command_name=$1

  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
}

require_variable() {
  local variable_name=$1

  if [[ -z ${!variable_name:-} ]]; then
    printf 'Required environment variable is empty: %s\n' "${variable_name}" >&2
    exit 1
  fi
}

create_runtime_directory() {
  if [[ -z ${XDG_RUNTIME_DIR:-} || ! -d ${XDG_RUNTIME_DIR} || ! -w ${XDG_RUNTIME_DIR} || -L ${XDG_RUNTIME_DIR} ]]; then
    printf 'XDG_RUNTIME_DIR must identify a writable per-user runtime directory.\n' >&2
    exit 1
  fi

  local runtime_owner
  local runtime_mode
  runtime_owner=$(stat -c '%u' "${XDG_RUNTIME_DIR}")
  runtime_mode=$(stat -c '%a' "${XDG_RUNTIME_DIR}")
  if [[ ${runtime_owner} != "${EUID}" || ${runtime_mode} != 700 ]]; then
    printf 'XDG_RUNTIME_DIR must be owned by the current user with mode 0700.\n' >&2
    exit 1
  fi

  RUNTIME_DIRECTORY=$(mktemp -d "${XDG_RUNTIME_DIR}/opentofu-secrets-lab.XXXXXX")
  chmod 0700 "${RUNTIME_DIRECTORY}"
  trap cleanup_runtime_directory EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

cleanup_runtime_directory() {
  if [[ -n ${RUNTIME_DIRECTORY:-} && -d ${RUNTIME_DIRECTORY} ]]; then
    rm -rf -- "${RUNTIME_DIRECTORY}"
  fi
}

read_secret_file() {
  local prompt=$1
  local destination=$2
  local secret_value

  IFS= read -r -s -p "${prompt}" secret_value
  printf '\n' >&2
  if [[ -z ${secret_value} ]]; then
    printf 'The value must not be empty.\n' >&2
    exit 1
  fi
  printf '%s' "${secret_value}" > "${destination}"
  unset secret_value
  chmod 0600 "${destination}"
}

require_openbao_transport() {
  require_variable BAO_ADDR
  require_variable BAO_CACERT
  require_variable BAO_TOKEN

  if [[ ${BAO_ADDR} != https://* ]]; then
    printf 'BAO_ADDR must use HTTPS.\n' >&2
    exit 1
  fi
  if [[ -n ${BAO_SKIP_VERIFY:-} || -n ${BAO_AGENT_ADDR:-} ]]; then
    printf 'BAO_SKIP_VERIFY and BAO_AGENT_ADDR must be unset for this lab.\n' >&2
    exit 1
  fi
  if [[ ! -r ${BAO_CACERT} || ! -f ${BAO_CACERT} ]]; then
    printf 'BAO_CACERT must identify a readable CA certificate file.\n' >&2
    exit 1
  fi
}

require_secure_output_directory() {
  local directory=$1
  local directory_owner
  local directory_mode

  if [[ ${directory} != /* || ! -d ${directory} || -L ${directory} ]]; then
    printf 'The certificate output directory must be an existing absolute directory.\n' >&2
    exit 1
  fi

  directory_owner=$(stat -c '%u' "${directory}")
  directory_mode=$(stat -c '%a' "${directory}")
  if [[ ${directory_owner} != "${EUID}" || ${directory_mode} != 700 ]]; then
    printf 'The certificate output directory must be user-owned with mode 0700.\n' >&2
    exit 1
  fi
}
