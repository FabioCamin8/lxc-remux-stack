#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENGINE="${CONTAINER_ENGINE:-docker}"
AUTH_STATUS=418
ADMIN_PATH_REGEXP='(?i)^(/emby)*/admin(/|$)'

command -v "$ENGINE" >/dev/null 2>&1 || {
  printf 'ERROR: container engine not found: %s\n' "$ENGINE" >&2
  exit 1
}
command -v curl >/dev/null 2>&1 || {
  printf 'ERROR: curl is required\n' >&2
  exit 1
}
command -v python3 >/dev/null 2>&1 || {
  printf 'ERROR: python3 is required\n' >&2
  exit 1
}

image_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' \
    "${WRAPPER_ROOT}/config/stack.env.example"
}

traefik_image="$(image_value TRAEFIK_IMAGE)"
remux_image="$(image_value REMUX_IMAGE)"
[[ "$traefik_image" == *@sha256:* ]] || {
  printf 'ERROR: TRAEFIK_IMAGE is not digest-pinned\n' >&2
  exit 1
}
[[ "$remux_image" == *@sha256:* ]] || {
  printf 'ERROR: REMUX_IMAGE is not digest-pinned\n' >&2
  exit 1
}

# Podman intentionally rejects unqualified short names when no search registry
# is configured. The fully qualified reference is accepted by Docker as well.
if [[ "$traefik_image" == traefik:* ]]; then
  traefik_image="docker.io/library/${traefik_image}"
fi

printf -v expected_compose_rule \
  '      - traefik.http.routers.remux-admin.rule=Host(`${REMUX_HOSTNAME?}`) && PathRegexp(`%s`)' \
  "$ADMIN_PATH_REGEXP"
if ! grep -Fqx "$expected_compose_rule" "${WRAPPER_ROOT}/overlay/compose.yaml"; then
  printf 'ERROR: route harness and overlay admin matcher differ\n' >&2
  exit 1
fi

ensure_image() {
  local image="$1"
  if ! "$ENGINE" image inspect "$image" >/dev/null 2>&1; then
    "$ENGINE" pull "$image"
  fi
}

free_port() {
  python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
}

test_root="$(mktemp -d /tmp/lxc-remux-route-test.XXXXXX)"
chmod 700 "$test_root"
traefik_port="$(free_port)"
run_id="${traefik_port}-$$"
backend_network="lxc-remux-route-backend-${run_id}"
ingress_network="lxc-remux-route-ingress-${run_id}"
remux_container="lxc-remux-route-remux-${run_id}"
auth_container="lxc-remux-route-auth-${run_id}"
traefik_container="lxc-remux-route-traefik-${run_id}"

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  set +e
  "$ENGINE" rm -f "$traefik_container" "$auth_container" \
    "$remux_container" >/dev/null 2>&1
  "$ENGINE" network rm "$backend_network" "$ingress_network" >/dev/null 2>&1
  find "$test_root" -depth -delete
  exit "$status"
}
trap cleanup EXIT INT TERM

ensure_image "$traefik_image"
ensure_image "$remux_image"

mkdir -p "${test_root}/remux-data"
chmod 700 "${test_root}/remux-data"

cat >"${test_root}/forward-auth.py" <<'PY'
import http.server

STATUS = 418

class ForwardAuthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(STATUS)
        self.send_header("X-Lxc-Remux-Route-Test", "forward-auth")
        self.end_headers()

    def log_message(self, *_args):
        pass

http.server.ThreadingHTTPServer(("0.0.0.0", 8000), ForwardAuthHandler).serve_forever()
PY
chmod 600 "${test_root}/forward-auth.py"

{
  printf '%s\n' \
    'http:' \
    '  routers:' \
    '    remux-admin:' \
    '      entryPoints: [test]'
  printf '      rule: "Host(`remux.test`) && PathRegexp(`%s`)"\n' "$ADMIN_PATH_REGEXP"
  printf '%s\n' \
    '      priority: 100' \
    '      middlewares: [forward-auth]' \
    '      service: remux' \
    '    remux:' \
    '      entryPoints: [test]' \
    '      rule: "Host(`remux.test`)"' \
    '      priority: 10' \
    '      service: remux' \
    '  middlewares:' \
    '    forward-auth:' \
    '      forwardAuth:'
  printf '        address: "http://%s:8000/"\n' "$auth_container"
  printf '%s\n' \
    '        trustForwardHeader: false' \
    '  services:' \
    '    remux:' \
    '      loadBalancer:' \
    '        servers:'
  printf '          - url: "http://%s:3000"\n' "$remux_container"
} >"${test_root}/dynamic.yaml"
chmod 600 "${test_root}/dynamic.yaml"

"$ENGINE" network create --internal "$backend_network" >/dev/null
"$ENGINE" network create "$ingress_network" >/dev/null

"$ENGINE" run -d \
  --name "$remux_container" \
  --network "$backend_network" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  -v "${test_root}/remux-data:/data:rw" \
  "$remux_image" >/dev/null

"$ENGINE" run -d \
  --name "$auth_container" \
  --network "$backend_network" \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  -v "${test_root}/forward-auth.py:/forward-auth.py:ro" \
  "$remux_image" \
  /usr/bin/python3 /forward-auth.py >/dev/null

"$ENGINE" create \
  --name "$traefik_container" \
  --network "$ingress_network" \
  --publish "127.0.0.1:${traefik_port}:8080/tcp" \
  --read-only \
  -v "${test_root}/dynamic.yaml:/etc/traefik/dynamic.yaml:ro" \
  "$traefik_image" \
  --entrypoints.test.address=:8080 \
  --entrypoints.test.http.sanitizepath=true \
  --entrypoints.test.http.encodedcharacters.allowencodedslash=true \
  --entrypoints.test.http.encodedcharacters.allowencodedbackslash=true \
  --entrypoints.test.http.encodedcharacters.allowencodednullcharacter=true \
  --entrypoints.test.http.encodedcharacters.allowencodedsemicolon=true \
  --entrypoints.test.http.encodedcharacters.allowencodedpercent=true \
  --entrypoints.test.http.encodedcharacters.allowencodedquestionmark=true \
  --entrypoints.test.http.encodedcharacters.allowencodedhash=true \
  --providers.file.filename=/etc/traefik/dynamic.yaml \
  --providers.file.watch=false \
  --global.sendanonymoususage=false \
  --global.checknewversion=false \
  --log.level=INFO >/dev/null
"$ENGINE" network connect "$backend_network" "$traefik_container"
"$ENGINE" start "$traefik_container" >/dev/null

for backend_container in "$remux_container" "$auth_container"; do
  if [[ -n "$("$ENGINE" port "$backend_container")" ]]; then
    printf 'ERROR: backend test container unexpectedly publishes a host port: %s\n' \
      "$backend_container" >&2
    exit 1
  fi
  if "$ENGINE" inspect "$backend_container" \
    --format '{{range $name, $_ := .NetworkSettings.Networks}}{{println $name}}{{end}}' | \
    grep -Fqx "$ingress_network"; then
    printf 'ERROR: backend test container joined the ingress network: %s\n' \
      "$backend_container" >&2
    exit 1
  fi
done

request_result() {
  local path="$1"
  curl -sS --path-as-is --max-time 5 \
    -o /dev/null \
    -D - \
    -w 'X-Curl-Status: %{http_code}\n' \
    -H 'Host: remux.test' \
    "http://127.0.0.1:${traefik_port}${path}" | \
    awk '
      BEGIN { status = ""; auth = "-" }
      tolower($1) == "x-curl-status:" { status = $2 }
      tolower($1) == "x-lxc-remux-route-test:" { auth = $2 }
      END {
        sub(/\r$/, "", status)
        sub(/\r$/, "", auth)
        printf "%s %s\n", status, auth
      }
    '
}

traefik_ready=0
for _ in $(seq 1 80); do
  if [[ "$(request_result /admin 2>/dev/null || true)" == "$AUTH_STATUS forward-auth" ]]; then
    traefik_ready=1
    break
  fi
  sleep 0.25
done
if [[ "$traefik_ready" -ne 1 ]]; then
  "$ENGINE" logs "$traefik_container" >&2
  "$ENGINE" logs "$auth_container" >&2
  printf 'ERROR: pinned Traefik did not load the admin route\n' >&2
  exit 1
fi

remux_ready=0
for _ in $(seq 1 120); do
  if [[ "$(request_result /administrator 2>/dev/null || true)" == '404 -' ]]; then
    remux_ready=1
    break
  fi
  sleep 0.25
done
if [[ "$remux_ready" -ne 1 ]]; then
  "$ENGINE" logs "$traefik_container" >&2
  "$ENGINE" logs "$remux_container" >&2
  printf 'ERROR: pinned Remux did not become ready behind Traefik\n' >&2
  exit 1
fi

assert_route() {
  local expected="$1"
  local expected_auth="$2"
  local path="$3"
  local actual actual_auth
  read -r actual actual_auth < <(request_result "$path")
  if [[ "$actual" != "$expected" || "$actual_auth" != "$expected_auth" ]]; then
    printf 'FAIL: %s expected HTTP/auth %s/%s, got %s/%s\n' \
      "$path" "$expected" "$expected_auth" "$actual" "$actual_auth" >&2
    return 1
  fi
  printf 'PASS: %-18s HTTP %s auth=%s\n' "$path" "$actual" "$actual_auth"
}

printf '== protected admin routes ==\n'
for path in \
  /admin /admin/ /admin/foo \
  /ADMIN /ADMIN/ /ADMIN/foo \
  /Admin /aDmIn/foo \
  /emby/admin /emby/admin/ /emby/ADMIN /emby/aDmIn/foo \
  /emby/emby/admin; do
  assert_route "$AUTH_STATUS" forward-auth "$path"
done

printf '== non-admin controls ==\n'
for path in \
  /administrator /adminfoo /foo/admin \
  /emby/administrator /emby/adminfoo /emby/foo/admin /foo/emby/admin; do
  assert_route 404 - "$path"
done

printf '== encoded and normalized paths ==\n'
# Traefik decodes unreserved characters and sanitizes duplicate slashes before
# matching, so these requests must traverse ForwardAuth.
for path in \
  '/%61dmin' '/%41DMIN' '//admin' \
  '/%65mby/admin' '//emby/admin' '/foo/../emby/admin'; do
  assert_route "$AUTH_STATUS" forward-auth "$path"
done

# With encoded slash permitted, Traefik keeps %2F in the routing path and the
# pinned Remux also treats these as non-admin paths. A future parser change that
# turns either request into an admin descendant without ForwardAuth fails here.
for path in \
  '/admin%2Ffoo' '/ADMIN%2Ffoo' \
  '/emby%2Fadmin' '/emby/admin%2Ffoo'; do
  assert_route 404 - "$path"
done

printf '%s\n' \
  'Remux admin route regression matrix passed against the pinned Traefik and Remux images.'
