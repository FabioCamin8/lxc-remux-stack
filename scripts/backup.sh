#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

destination="${1:-}"
[[ -n "$destination" ]] || die "usage: $0 ABSOLUTE_DESTINATION"
[[ "$destination" == /* ]] || die "backup destination must be absolute"

requested_destination="$destination"
destination_parent="$(dirname -- "$requested_destination")"
[[ -d "$destination_parent" ]] || \
  die "backup destination parent must already exist: $destination_parent"
canonical_parent="$(realpath -e -- "$destination_parent")"
[[ "$canonical_parent" == "$destination_parent" ]] || \
  die "backup destination parent must be canonical and not use symlinks"
[[ "$(stat -c '%u' -- "$destination_parent")" == "$(id -u)" ]] || \
  die "backup destination parent must be owned by the invoking user"
parent_mode="$(stat -c '%a' -- "$destination_parent")"
(( (8#${parent_mode} & 0022) == 0 )) || \
  die "backup destination parent must not be writable by group or others"
destination="${canonical_parent}/$(basename -- "$requested_destination")"
[[ ! -e "$destination" && ! -L "$destination" ]] || \
  die "backup destination already exists: $destination"

docker_data_root="$(realpath -m -- "${DOCKER_DATA_ROOT}")"
runtime_root="$(realpath -m -- "${RUNTIME_DIR}")"
case "${destination}/" in
  "${docker_data_root}/"*|"${runtime_root}/"*)
    die "backup destination must be outside Docker data and wrapper runtime"
    ;;
esac

require_runtime
compose ps --status running >/dev/null

stateful_services=(aiostreams remux authelia authelia_postgres authelia_redis)
mapfile -t running_services < <(compose ps --status running --services)
running_stateful=()
for service in "${stateful_services[@]}"; do
  for running_service in "${running_services[@]}"; do
    if [[ "$service" == "$running_service" ]]; then
      running_stateful+=("$service")
      break
    fi
  done
done

restart_stateful() {
  if ((${#running_stateful[@]})); then
    compose up -d "${running_stateful[@]}" >/dev/null
  fi
}
trap restart_stateful EXIT
if ((${#running_stateful[@]})); then
  compose stop "${running_stateful[@]}"
fi

install -d -m 0700 "$destination"
[[ -d "$destination" && ! -L "$destination" ]] || \
  die "backup destination is not a newly created directory"
tar --xattrs --acls --numeric-owner -C "${DOCKER_DATA_ROOT}" \
  -cpf "${destination}/docker-data.tar" .
tar --numeric-owner -C "${UPSTREAM_ROOT}" \
  -cpf "${destination}/upstream-env.tar" .env
tar --numeric-owner -C "${RUNTIME_DIR}" \
  -cpf "${destination}/runtime-config.tar" .
git -C "${UPSTREAM_ROOT}" rev-parse HEAD >"${destination}/viren-commit.txt"
compose images --format json >"${destination}/images.json"
sha256sum "${destination}"/*.tar "${destination}/viren-commit.txt" \
  "${destination}/images.json" >"${destination}/SHA256SUMS"
chmod 0600 "${destination}"/*
restart_stateful
trap - EXIT
printf 'Backup created at %s\n' "$destination"
