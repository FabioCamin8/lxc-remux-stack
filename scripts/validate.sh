#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_runtime

printf '== compose config ==\n'
compose config --quiet

printf '== selected services ==\n'
compose config --services

printf '== compose status ==\n'
compose ps

printf '== container images/status/ports ==\n'
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

printf '== expected network ==\n'
runtime_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print}' \
    "${RUNTIME_DIR}/stack.env" | tail -n 1
}

runtime_network="$(runtime_value DOCKER_NETWORK)"
[[ -n "$runtime_network" ]] || die "DOCKER_NETWORK is missing from runtime/stack.env"
docker network inspect "$runtime_network" \
  --format '{{range $id, $c := .Containers}}{{$c.Name}} {{end}}'

runtime_project="$(runtime_value COMPOSE_PROJECT_NAME)"
[[ -n "$runtime_project" ]] || die "COMPOSE_PROJECT_NAME is missing from runtime/stack.env"
socket_network="${runtime_project}_socket_proxy"
auth_network="${runtime_project}_auth_backend"
docker network inspect "$socket_network" "$auth_network" \
  --format '{{.Name}}: {{range $id, $c := .Containers}}{{$c.Name}} {{end}}'

assert_networks() {
  local service="$1"
  shift
  local cid actual expected
  cid="$(compose ps -q "$service")"
  [[ -n "$cid" ]] || die "$service container is missing"
  actual="$(docker inspect --format \
    '{{range $name, $network := .NetworkSettings.Networks}}{{$name}}{{"\n"}}{{end}}' \
    "$cid" | sort)"
  expected="$(printf '%s\n' "$@" | sort)"
  [[ "$actual" == "$expected" ]] || \
    die "$service networks differ: expected [$expected], got [$actual]"
  printf 'PASS: %s networks=%s\n' "$service" "$(tr '\n' ',' <<<"$actual" | sed 's/,$//')"
}

printf '== network isolation assertions ==\n'
assert_networks docker-socket-proxy "$socket_network"
assert_networks traefik "$runtime_network" "$socket_network"
assert_networks authelia "$runtime_network" "$auth_network"
assert_networks authelia_postgres "$auth_network"
assert_networks authelia_redis "$auth_network"
assert_networks aiostreams "$runtime_network"
assert_networks remux "$runtime_network"
printf 'PASS: authentication backends are isolated from application peers\n'

printf '== listening host ports ==\n'
ss -lntup

printf '== exposure assertions ==\n'
for service in docker-socket-proxy authelia_postgres authelia_redis aiostreams remux; do
  cid="$(compose ps -q "$service")"
  [[ -n "$cid" ]] || die "$service container is missing"
  port_bindings="$(docker inspect --format '{{json .HostConfig.PortBindings}}' "$cid")"
  [[ "$port_bindings" == null || "$port_bindings" == '{}' ]] || \
    die "$service has a published host port: $port_bindings"
done
printf 'PASS: no socket proxy, AIOStreams, Remux, PostgreSQL, or Redis host port is published\n'

printf '== local health assertions ==\n'
for service in \
  docker-socket-proxy traefik authelia authelia_postgres authelia_redis \
  aiostreams remux; do
  cid="$(compose ps -q "$service")"
  [[ -n "$cid" ]] || die "$service container is missing"
  state="$(docker inspect --format '{{.State.Status}}' "$cid")"
  [[ "$state" == running ]] || die "$service is not running: $state"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid")"
  [[ "$health" == healthy || "$health" == none ]] || die "$service health is $health"
  printf 'PASS: %s state=%s health=%s\n' "$service" "$state" "$health"
done

printf '%s\n' \
  'Runtime structure validation passed.' \
  'Application authentication, persistence, WebSocket, playback, seek, and resume' \
  'still require the explicit tests in docs/VALIDATION.md.'
