# Functional parity with the previous streaming stack

Status: **static baseline reconstructed; Docker runtime verification pending**

This project replaces the runtime implementation of the existing K3s streaming stack, but it should preserve the useful application and operational behavior already established there.

The authoritative historical reference is:

- `FabioCamin8/k3s-streaming-stack`

The existing K3s node remains online during migration. Its real private address and any access credentials are operational data supplied out of band and MUST NOT be committed to this public repository.

## Rule

Do not mechanically translate Kubernetes manifests to Docker Compose.

Instead:

1. inspect the historical repository;
2. when authorized and reachable, inspect the running K3s deployment read-only;
3. derive the current functional contract;
4. implement the simplest Docker Compose equivalent;
5. prove parity with explicit tests;
6. document intentional differences.

The old K3s environment is a reference and rollback source until the operator explicitly approves cutover and later decommissioning.

## Parity matrix

| Area | Previous stack contract to preserve | Docker target |
|---|---|---|
| AIOStreams persistence | durable application data and stable secret across recreation/reboot | persistent bind/volume under the Docker data root |
| AIOStreams machine endpoints | manifest/API remain usable without browser-oriented auth interference | Traefik routes preserve machine-client behavior |
| AIOStreams configuration security | human/configuration surfaces protected appropriately | native application auth and/or selective Authelia, based on verified current upstream behavior |
| Remux persistence | durable `/data` across workload recreation and host reboot | persistent bind/volume under the Docker data root |
| Remux client compatibility | Jellyfin-compatible clients can authenticate, browse, search and play | no blanket ForwardAuth on Jellyfin/API/WebSocket/media paths |
| Remux administration | administrative UI protected separately from machine protocol paths | selective Authelia route if compatible with current Remux routing |
| Remux -> AIOStreams | internal service-to-service integration without leaking internal-only URLs to clients | Docker service DNS/common network; client-visible redirects must remain externally reachable |
| WebSockets | client WebSocket endpoints survive reverse proxying | explicit Traefik validation |
| Playback/redirect semantics | no redirect exposes internal cluster/service addresses | no redirect exposes Docker-only hostnames or RFC1918-only targets to Internet clients unless intentionally LAN-only |
| TLS | certificate lifecycle independent from application persistence | Traefik TLS model selected and validated before public cutover |
| DNS | DNS state is operator-controlled and not assumed from application health | no public DNS change before operator approval |
| Public exposure | only intended streaming/reverse-proxy ports forwarded | no Internet forwarding before operator validation |
| Updates | AIOStreams and Remux have different risk profiles; Remux remains conservative | updater policy must preserve review/rollback gates |
| Recovery | application data and previous working image/config can be restored | documented backup, recreate, rollback and host migration procedures |
| Reboot recovery | stack recovers after host reboot | Docker enabled at boot and Compose services use appropriate restart policy |

## Pre-deployment classification

| Area | Status | Evidence boundary |
|---|---|---|
| Historical repository reconstruction | PASS | merged reference and later feature branches reviewed; exact revisions in `UPSTREAMS.md` |
| Live K3s mutable state | BLOCKED | strict SSH host-key trust is unavailable; the node was not changed |
| AIOStreams persistence/machine routes | BLOCKED | overlay preserves `/app/data` and removes ForwardAuth, but no Docker runtime test yet |
| Remux persistence/native client routes | BLOCKED | overlay preserves `/data` and current source routes were reviewed, but no Docker runtime test yet |
| Remux `/admin` selective authentication | BLOCKED | route split is implemented; real Authelia session/TOTP proof is pending |
| PostgreSQL and Redis for Authelia | INTENTIONAL DIFFERENCE | Viren architecture replaces the old lightweight Authelia storage/session layout |
| Docker socket proxy | INTENTIONAL DIFFERENCE | Traefik receives bounded read-only API access instead of a direct socket mount |
| Provider-backed playback/seek/resume | BLOCKED | not established by old evidence and not yet tested on Docker |
| Updater | INTENTIONAL DIFFERENCE | Watchtower/WUD disabled; manual digest-recorded updates only |
| Internet exposure/cutover | BLOCKED | outside the authorized local/LAN phase |

## Evidence to collect from the previous environment

Before declaring parity, the executor should inspect the old repository and, when access is available, collect sanitized/read-only evidence from the running K3s node for:

- deployed AIOStreams and Remux image versions/digests;
- persistent data boundaries;
- application environment/configuration shape without printing secret values;
- ingress host/path behavior;
- AIOStreams internal URL used by Remux;
- authentication boundaries;
- WebSocket paths;
- health checks and restart behavior;
- externally visible redirect/playback behavior;
- public-port assumptions;
- update/rollback assumptions;
- any known live workaround not obvious from Git.

Do not copy Kubernetes-only machinery unless it represents a real functional requirement.

Examples of things that generally do **not** need parity in the Docker implementation:

- K3s API/server components;
- Kubernetes Services as objects;
- Deployments/ReplicaSets;
- cert-manager as a product if Traefik can provide the required certificate lifecycle cleanly;
- ServiceLB;
- local-path provisioner;
- Kubernetes Secrets format;
- Kubernetes-specific update controllers.

## Acceptance

Parity is accepted only when the new Docker stack passes the relevant functional tests and the operator confirms the behavior is sufficient for cutover.

A difference is acceptable when it is:

- simpler;
- intentionally documented;
- at least as secure;
- compatible with real clients;
- reversible.

The operator must explicitly approve Internet forwarding and production cutover after LAN/local validation. Until then the existing K3s deployment remains untouched and available as the reference/rollback environment.
