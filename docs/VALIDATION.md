# Local and LAN validation matrix

Status: **NOT RUN on the target LXC**

Use only `PASS`, `INTENTIONAL DIFFERENCE`, `BLOCKED`, or `FAIL`. A running container is not application acceptance.

## Repository security gate

Codex Deep Scan: BLOCKED by Security worker/provider environment propagation.

This is a tooling limitation, not a repository security finding. The repository
gate was completed against the exact working tree using these compensating
controls:

- targeted security review;
- routing regression suite;
- Docker-network isolation tests;
- Compose exposure review;
- secret scan;
- full diff review.

This result does not describe the Deep Scan as PASS and does not establish any
target-LXC, production, Internet-forwarding, DNS/NAT, or K3s acceptance.

## Structural gates

```bash
./scripts/stack.sh config
./scripts/stack.sh ps
./scripts/validate.sh
./scripts/test-remux-admin-routing.sh
docker compose images
docker network inspect aio_network
ss -lntup
```

Review the rendered model for selected profiles only. Expected services are
Traefik, its socket proxy, Authelia, Authelia PostgreSQL, Authelia Redis,
AIOStreams, and Remux. PostgreSQL, Redis, AIOStreams, Remux, and the Docker
socket proxy must have empty Docker `HostConfig.PortBindings`; loopback and
IPv6 publications are failures too. PostgreSQL and Redis must join only the
internal authentication-backend network; AIOStreams and Remux must join only
the frontend application network. Do not enable `all`, Watchtower, WUD, DDNS,
or another catalog service.

## HTTP and authentication gates

Use LAN split DNS or `curl --resolve` with the untracked hostnames/IP. Never record those values in Git.

| Check | Expected result |
|---|---|
| AIOStreams `/api/v1/status` | 200 through Traefik and container health healthy |
| AIOStreams `/api/v1/health` | 200 with database healthy |
| AIOStreams native login | valid login succeeds; invalid login fails |
| AIOStreams `/stremio/manifest.json` | machine response, never an Authelia redirect |
| configured AIOStreams manifest/API | valid URL credential succeeds; invalid one fails |
| Remux `/health` and `/system/ping` | 200 without Authelia redirect |
| Remux `/admin/` unauthenticated | Authelia challenge/redirect |
| Remux `/admin/` authenticated | dashboard loads, then Remux native admin rules still apply |
| Remux `/web/` and `/jellyfin/` | no Authelia redirect |
| `POST /users/authenticatebyname` | native token issued for valid user only |
| non-admin token on admin API | denied |
| `/websocket` and `/socket` | successful upgrade with native token; no browser redirect |

`test-remux-admin-routing.sh` is the disposable exact-image regression gate for
the selective ForwardAuth boundary. It verifies case-insensitive, segment-safe
matching, Remux's `/emby` compatibility rewrite, and encoded/normalized path
behavior against the digest-pinned Traefik and Remux images. Set
`CONTAINER_ENGINE=podman` when validating on a Podman-only workstation.

Never print passwords, tokens, cookies, OTPs, user records, configured manifest URLs, or response bodies containing credentials.

## Functional gates

- create or restore one authorized Remux user;
- configure AIOStreams through its native authentication path;
- add the internal AIOStreams manifest to Remux with `httpRedirectStream=false`;
- browse library and issue a correctly parameterized Jellyfin `/items` request;
- search and select a stream;
- start actual playback from an intended client;
- seek and resume;
- validate range requests, HLS segments, subtitles, and both WebSocket routes where the client uses them;
- inspect every `Location` header and playback URL for Docker-only names, Kubernetes names, cluster suffixes, or unreachable private backends;
- explicitly review Remux's unauthenticated UUID `/stream/{id}` design.

Provider-backed playback and physical-client behavior were not proven by the historical K3s evidence. They start as `BLOCKED`/`NOT RUN`, never inherited `PASS`.

## Persistence and recovery gates

1. record non-secret checksums/counts for AIOStreams state and Remux database/settings;
2. force-recreate AIOStreams and Remux individually;
3. prove state and stable encryption keys survive;
4. force-recreate Authelia/Redis/PostgreSQL and prove session/TOTP/storage recovery as applicable;
5. create a private backup and verify its checksums;
6. reboot the LXC once;
7. prove Docker is active, all selected services recover, health stabilizes, and state remains;
8. inspect logs for migrations, recurring errors, authentication failures, redirect leaks, and crash loops.

## Stop boundary

After all possible local/LAN rows are classified, stop. Do not modify DNS, NAT, router/firewall exposure, public forwarding, the existing K3s deployment, or old persistent data. Present the operator with the sanitized evidence and exact proposed cutover/rollback steps.
