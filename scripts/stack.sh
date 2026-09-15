#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

case "${1:-}" in
  config)
    command -v python3 >/dev/null || die "python3 is required for the safe config summary"
    compose config --quiet
    compose config --format json | python3 -c '
import json
import sys

model = json.load(sys.stdin)
for name, service in sorted(model.get("services", {}).items()):
    networks = service.get("networks", {})
    if isinstance(networks, dict):
        networks = sorted(networks)
    else:
        networks = sorted(networks or [])
    print(
        "service={name} image={image} networks={networks} published_ports={ports}".format(
            name=name,
            image=service.get("image", "<none>"),
            networks=",".join(networks) or "<none>",
            ports=len(service.get("ports", []) or []),
        )
    )
'
    ;;
  pull)
    compose pull
    ;;
  up)
    compose up -d
    ;;
  ps)
    compose ps
    ;;
  logs)
    shift
    compose logs "$@"
    ;;
  recreate)
    shift
    [[ $# -gt 0 ]] || die "recreate requires one or more service names"
    compose up -d --force-recreate "$@"
    ;;
  *)
    die "usage: $0 {config|pull|up|ps|logs [args...]|recreate SERVICE...}"
    ;;
esac
