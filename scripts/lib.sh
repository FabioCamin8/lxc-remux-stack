#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR
readonly WRAPPER_ROOT="${LXC_REMUX_ROOT:-$(cd -- "${LIB_DIR}/.." && pwd)}"
readonly RUNTIME_DIR="${LXC_REMUX_RUNTIME_DIR:-${WRAPPER_ROOT}/runtime}"
# shellcheck disable=SC2034  # Used by bootstrap.sh after sourcing this library.
readonly UPSTREAM_COMMIT="25b1b1f29ed33a0e67d28d73a6ad71d728d3800f"

stack_env_value() {
  local key="$1"
  [[ -f "${RUNTIME_DIR}/stack.env" ]] || return 0
  awk -F= -v key="$key" \
    '$1 == key {sub(/^[^=]*=/, ""); print}' \
    "${RUNTIME_DIR}/stack.env" | tail -n 1
}

configured_docker_dir="$(stack_env_value DOCKER_DIR)"
configured_docker_data_dir="$(stack_env_value DOCKER_DATA_DIR)"
configured_docker_app_dir="$(stack_env_value DOCKER_APP_DIR)"
readonly UPSTREAM_ROOT="${DOCKER_DIR:-${configured_docker_dir:-/opt/docker}}"
readonly DOCKER_DATA_ROOT="${DOCKER_DATA_DIR:-${configured_docker_data_dir:-${UPSTREAM_ROOT}/data}}"
readonly DOCKER_APP_ROOT="${DOCKER_APP_DIR:-${configured_docker_app_dir:-${UPSTREAM_ROOT}/apps}}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || die "required file missing: $1"
}

require_configured_path() {
  local key="$1"
  local actual="$2"
  local configured
  configured="$(stack_env_value "$key")"
  [[ "$configured" == /* ]] || die "$key must be an absolute path in runtime/stack.env"
  [[ "$(realpath -m -- "$configured")" == "$(realpath -m -- "$actual")" ]] || \
    die "$key in runtime/stack.env does not match the path used by this command"
}

require_runtime() {
  require_file "${UPSTREAM_ROOT}/compose.yaml"
  require_file "${UPSTREAM_ROOT}/.env"
  require_file "${RUNTIME_DIR}/stack.env"
  require_file "${RUNTIME_DIR}/aiostreams.env"
  require_file "${RUNTIME_DIR}/authelia/users.yml"
  require_configured_path LXC_REMUX_ROOT "$WRAPPER_ROOT"
  require_configured_path LXC_REMUX_RUNTIME_DIR "$RUNTIME_DIR"
  require_configured_path DOCKER_DIR "$UPSTREAM_ROOT"
  require_configured_path DOCKER_DATA_DIR "$DOCKER_DATA_ROOT"
  require_configured_path DOCKER_APP_DIR "$DOCKER_APP_ROOT"
  if grep -Eq '<[^>]+>' \
    "${RUNTIME_DIR}/stack.env" \
    "${RUNTIME_DIR}/aiostreams.env" \
    "${RUNTIME_DIR}/authelia/users.yml"; then
    die "runtime configuration still contains an unresolved <...> marker"
  fi
}

compose() {
  require_runtime
  docker compose \
    --project-directory "${UPSTREAM_ROOT}" \
    --env-file "${UPSTREAM_ROOT}/.env" \
    --env-file "${RUNTIME_DIR}/stack.env" \
    -f "${UPSTREAM_ROOT}/compose.yaml" \
    -f "${WRAPPER_ROOT}/overlay/compose.yaml" \
    --profile required \
    --profile aiostreams \
    --profile remux \
    "$@"
}
