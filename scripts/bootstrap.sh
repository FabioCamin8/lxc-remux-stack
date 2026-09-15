#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"
umask 077

command -v git >/dev/null || die "git is required"
command -v openssl >/dev/null || die "openssl is required"

if [[ ! -d "${UPSTREAM_ROOT}/.git" ]]; then
  git clone https://github.com/Viren070/docker-compose-template.git "${UPSTREAM_ROOT}"
fi

[[ "$(git -C "${UPSTREAM_ROOT}" status --porcelain)" == "" ]] || \
  die "upstream worktree is dirty; preserve/review it before bootstrap"

git -C "${UPSTREAM_ROOT}" fetch --tags origin
git -C "${UPSTREAM_ROOT}" checkout --detach "${UPSTREAM_COMMIT}"

install -d -m 0700 "${RUNTIME_DIR}/authelia"
install -d -m 0750 \
  "${UPSTREAM_ROOT}/data/aiostreams" \
  "${UPSTREAM_ROOT}/data/authelia/cache" \
  "${UPSTREAM_ROOT}/data/authelia/db" \
  "${UPSTREAM_ROOT}/data/remux" \
  "${UPSTREAM_ROOT}/data/traefik"

if [[ ! -f "${RUNTIME_DIR}/stack.env" ]]; then
  install -m 0600 "${WRAPPER_ROOT}/config/stack.env.example" "${RUNTIME_DIR}/stack.env"
  for path_assignment in \
    "DOCKER_DIR=${UPSTREAM_ROOT}" \
    "DOCKER_DATA_DIR=${DOCKER_DATA_ROOT}" \
    "DOCKER_APP_DIR=${DOCKER_APP_ROOT}" \
    "LXC_REMUX_ROOT=${WRAPPER_ROOT}" \
    "LXC_REMUX_RUNTIME_DIR=${RUNTIME_DIR}"; do
    key="${path_assignment%%=*}"
    value="${path_assignment#*=}"
    value="${value//\\/\\\\}"
    value="${value//|/\\|}"
    value="${value//&/\\&}"
    sed -i "s|^${key}=.*|${key}=${value}|" "${RUNTIME_DIR}/stack.env"
  done
  while grep -q '<GENERATE_64_CHAR_SECRET>' "${RUNTIME_DIR}/stack.env"; do
    secret="$(openssl rand -hex 32)"
    sed -i "0,/<GENERATE_64_CHAR_SECRET>/s||${secret}|" "${RUNTIME_DIR}/stack.env"
  done
fi

if [[ ! -f "${RUNTIME_DIR}/aiostreams.env" ]]; then
  install -m 0600 "${WRAPPER_ROOT}/config/aiostreams.env.example" "${RUNTIME_DIR}/aiostreams.env"
  secret="$(openssl rand -hex 32)"
  sed -i "0,/<GENERATE_64_HEX_SECRET>/s||${secret}|" "${RUNTIME_DIR}/aiostreams.env"
  secret="$(openssl rand -hex 32)"
  sed -i "0,/<GENERATE_64_CHAR_SECRET>/s||${secret}|" "${RUNTIME_DIR}/aiostreams.env"
fi

chown "$(id -u):$(id -g)" \
  "${RUNTIME_DIR}/stack.env" \
  "${RUNTIME_DIR}/aiostreams.env"
chmod 0600 \
  "${RUNTIME_DIR}/stack.env" \
  "${RUNTIME_DIR}/aiostreams.env"

if [[ ! -f "${RUNTIME_DIR}/authelia/users.yml" ]]; then
  install -m 0600 "${WRAPPER_ROOT}/config/authelia-users.yml.example" \
    "${RUNTIME_DIR}/authelia/users.yml"
fi

if [[ ! -f "${RUNTIME_DIR}/authelia/configuration.yml" ]]; then
  install -m 0600 "${UPSTREAM_ROOT}/apps/authelia/config/configuration.yml" \
    "${RUNTIME_DIR}/authelia/configuration.yml"
fi

puid="$(sed -n 's/^PUID=//p' "${RUNTIME_DIR}/stack.env" | tail -n 1)"
pgid="$(sed -n 's/^PGID=//p' "${RUNTIME_DIR}/stack.env" | tail -n 1)"
[[ "$puid" =~ ^[0-9]+$ ]] || die "PUID must be numeric in runtime/stack.env"
[[ "$pgid" =~ ^[0-9]+$ ]] || die "PGID must be numeric in runtime/stack.env"
chown -R "${puid}:${pgid}" "${RUNTIME_DIR}/authelia"
chmod 0700 "${RUNTIME_DIR}/authelia"
chmod 0600 "${RUNTIME_DIR}/authelia/configuration.yml" \
  "${RUNTIME_DIR}/authelia/users.yml"

printf '%s\n' \
  "Bootstrap files are ready." \
  "Edit ${RUNTIME_DIR}/stack.env, ${RUNTIME_DIR}/aiostreams.env, and" \
  "${RUNTIME_DIR}/authelia/users.yml; replace every <...> marker." \
  "Then run: ${WRAPPER_ROOT}/scripts/stack.sh config"
