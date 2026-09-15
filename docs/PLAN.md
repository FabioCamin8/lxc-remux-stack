# Implementation and migration plan

Status: **wrapper implemented; target runtime pending**

## Goal

Deploy the Remux media stack on one dedicated Docker host, initially a Proxmox LXC, using Docker Compose. The Viren070 Docker Compose template provides shared infrastructure and supported media services, while Remux is added as a small local extension.

The new implementation must preserve the useful behavior already established by the previous K3s deployment while removing Kubernetes-specific complexity. The historical and live reference is `FabioCamin8/k3s-streaming-stack` and its existing `k3s01` node. The node's real private address/access details are supplied operationally and must never be committed to this public repository.

The migration must remain reversible until final cutover. Existing production services must not be modified or removed until the new stack passes all functional gates and the operator explicitly approves Internet forwarding to the new Docker host.

The resulting Docker Compose application architecture must also remain portable to a conventional Debian VM running Docker, without K3s.

See:

- [`PARITY.md`](PARITY.md) for the previous-stack functional contract;
- [`PORTABILITY.md`](PORTABILITY.md) for the LXC-to-VM Docker portability contract.

## Architecture decision

Do **not** maintain a full private fork of `Viren070/docker-compose-template` inside this repository.

Use this repository as a public, sanitized deployment wrapper with:

```text
lxc-remux-stack/
├── README.md
├── AGENTS.md
├── SECURITY.md
├── docs/
├── config/
│   └── *.example
├── overlay/
│   └── apps/remux/
└── scripts/
```

On the Docker host, the runtime layout will be:

```text
/opt/docker/                     # Viren070 template working tree
/opt/lxc-remux-stack/            # this repository
```

Local automation will:

1. clone or update the Viren070 template in `/opt/docker`;
2. pin/record the tested upstream revision;
3. apply the small Remux overlay and sanitized configuration templates;
4. keep populated `.env` files only on the runtime host;
5. validate the rendered Compose model before starting containers.

This keeps the upstream template easy to update while making the deployment-specific delta reviewable.

## Execution model

Codex Sol is the primary executor and owns mutations, runtime actions, integration, commits and final validation.

Sol may parallelize bounded work by spawning Luna agents at xhigh effort for independent research/audit/review tasks, including:

- old K3s repository/runtime inspection;
- Viren070/Remux/AIOStreams upstream review;
- route/authentication analysis;
- parity matrix review;
- security review;
- test-matrix construction;
- portability review;
- post-change diff/test review.

Parallel agents must not concurrently mutate the same file or runtime resource. Sol integrates and verifies all findings before execution or acceptance. See `../AGENTS.md`.

## Previous K3s stack as migration baseline

The old environment remains online through build and validation.

Use two evidence sources:

1. Git history/configuration in `FabioCamin8/k3s-streaming-stack`;
2. read-only inspection of the running `k3s01` node when access is available.

The objective is functional parity, not manifest parity.

Before implementing a Docker equivalent, identify the current contract for:

- AIOStreams persistence, secrets, authentication and manifest/API behavior;
- Remux persistence, routes, Jellyfin-compatible behavior and WebSockets;
- Remux -> AIOStreams integration;
- stream/proxy/redirect behavior and the rule that internal-only addresses must never leak to clients;
- TLS/DNS/public-port behavior;
- trusted proxy/source IP behavior;
- reboot recovery;
- update and rollback strategy;
- any live workaround not represented clearly in Git.

The old K3s environment is read-only until the operator separately authorizes changes. It remains a rollback/reference environment even after the new LXC is built.

## Target services

Initial target:

| Component | Source | Purpose | Initial exposure |
|---|---|---|---|
| Traefik | Viren070 template | reverse proxy / TLS | LAN/local only until cutover |
| Authelia | Viren070 template | selective protection for administrative UIs | via Traefik |
| Authelia PostgreSQL | Viren070 template | Authelia storage | internal only |
| Authelia Redis | Viren070 template | Authelia session/cache | internal only |
| AIOStreams | Viren070 template | Stremio aggregation | via Traefik |
| Remux | local overlay using upstream image | Jellyfin-compatible media server | via Traefik |
| Cloudflare DDNS | Viren070 template, optional | DNS record maintenance | outbound only; no production mutation before approval |
| image updater | Viren070 template | controlled container updates | internal only; policy gated |

Additional Viren070 services are out of scope until the minimal stack is validated.

## Remux routing model

Remux serves both administrative/browser surfaces and Jellyfin-compatible client/API traffic. Forward authentication must therefore not be blindly applied to the entire hostname.

Planned routing:

```text
/admin...       -> Authelia -> Remux
all other paths -> Remux directly
```

The implementation must explicitly verify current upstream behavior for:

- `/admin` protection;
- Jellyfin-compatible API authentication;
- `/web` and `/jellyfin` behavior;
- WebSocket endpoints;
- playback from a real client;
- no Authelia redirect injected into media/API responses;
- no client-visible redirect containing a Docker-only service name, old Kubernetes service name, or otherwise unreachable internal URL.

If Remux upstream changes its path model, routing must be re-evaluated before deployment.

## Host-portability requirement

The initial host is an LXC, but application and Compose configuration must remain reusable on a standard Debian VM with Docker.

Implementation must avoid unnecessary dependency on:

- LXC-only device mappings;
- CT IDs;
- Proxmox-specific host paths in Compose;
- hard-coded IP addresses/interface names;
- K3s/Kubernetes.

Host-specific provisioning belongs outside the application contract. A future LXC -> VM migration should primarily require Debian/Docker provisioning, restoration of local secrets/data, Compose deployment and validation.

## Phases

### Phase 0 - Repository baseline

- [x] initialize public repository documentation;
- [x] define secret-handling policy;
- [x] document sanitized LXC provisioning;
- [x] add Codex/agent operating instructions;
- [x] define K3s functional parity contract;
- [x] define LXC -> VM Docker portability contract;
- [x] add example configuration and Remux overlay;
- [x] add validation scripts.

Gate: repository contains no operational secrets or personal infrastructure values.

### Phase 0.5 - Reconstruct current K3s behavior

Before treating the Docker design as final:

- [x] read the current `k3s-streaming-stack` repository documentation/manifests/validation records;
- [x] capture the current reference repository commit;
- [ ] when reachable, inspect `k3s01` read-only;
- [ ] identify current AIOStreams/Remux image versions and runtime digests without exposing secrets;
- [x] identify repository-recorded persistence boundaries;
- [x] identify repository-recorded ingress/routes/auth boundaries;
- [x] identify repository-recorded Remux -> AIOStreams service behavior;
- [x] identify repository-recorded playback/redirect behavior;
- [x] identify repository-recorded Internet port/TLS assumptions;
- [ ] record any behavior that differs from the Git contract;
- [ ] turn findings into explicit Docker validation cases.

No mutation of the old stack is allowed in this phase.

Static reconstruction uses merged reference commit
`6c96e820200a1990e8ef2c01bcbac401e5e0d868` plus the later feature evidence
listed in [`UPSTREAMS.md`](UPSTREAMS.md). Live inspection is still required:
strict SSH stopped at an untrusted host-key boundary, so mutable workload,
image, ingress and forwarding facts remain unknown rather than inferred.

Gate: `PARITY.md` and/or a sanitized validation note accurately describe what the Docker implementation must preserve.

### Phase 1 - Provision LXC

Run the Community Scripts Docker LXC installer locally on the Proxmox node using the operator's real values supplied only in the shell.

Then validate:

- [ ] LXC boots cleanly;
- [ ] SSH key access works;
- [ ] Docker Engine active;
- [ ] Docker Compose v2 available;
- [ ] outbound DNS/HTTPS works;
- [ ] disposable container starts;
- [ ] CPU/RAM/storage are sufficient;
- [ ] temporary bootstrap password rotated or disabled as appropriate.

Record software versions in a sanitized deployment note if useful. Do not commit IPs, keys, passwords, or personal identifiers.

Gate: healthy standalone Docker LXC.

### Phase 2 - Install upstream template

- [ ] clone `Viren070/docker-compose-template` into `/opt/docker`;
- [ ] record the exact tested upstream commit in this repository;
- [ ] inspect upstream `.env` requirements at that revision;
- [ ] create local `/opt/docker/.env` from sanitized examples;
- [ ] generate Authelia/application secrets locally;
- [ ] keep all populated env files untracked;
- [x] ensure the frontend Docker network and isolated authentication-backend
  network render correctly;
- [ ] verify no implementation choice violates `PORTABILITY.md` without a documented reason.

Gate:

```bash
cd /opt/docker
docker compose config >/dev/null
```

must succeed with no unresolved required variables.

### Phase 3 - Bootstrap shared infrastructure

Start only the minimum required services first.

- [ ] Traefik healthy;
- [ ] Authelia healthy;
- [ ] Authelia PostgreSQL healthy;
- [ ] Authelia Redis healthy;
- [x] PostgreSQL and Redis isolated from AIOStreams and Remux in the rendered
  Compose model;
- [ ] no unexpected ports listening on the LXC host;
- [ ] Traefik discovers only explicitly enabled services.

Do not change production DNS/NAT or Internet forwarding yet.

Gate: local/LAN requests to the reverse proxy behave as designed.

### Phase 4 - Deploy AIOStreams

- [ ] configure a persistent data directory;
- [ ] generate AIOStreams secret locally;
- [ ] start the upstream Viren070 AIOStreams profile;
- [ ] verify health/logs;
- [ ] verify configuration page behavior;
- [ ] verify addon manifest/API behavior;
- [ ] verify persistence across container recreation;
- [ ] compare relevant behavior with the old K3s AIOStreams deployment.

Gate: AIOStreams works through the new Traefik instance without production cutover and satisfies the relevant parity checks.

### Phase 5 - Add Remux overlay

Create `overlay/apps/remux/compose.yaml` based on the current official `ghcr.io/lostb1t/remux` image and upstream runtime requirements.

Requirements:

- [ ] persistent `/data` bind mount;
- [ ] no direct public host port unless specifically needed for isolated testing;
- [ ] Traefik service points to Remux internal port;
- [ ] main router remains usable by Jellyfin-compatible clients;
- [ ] separate high-priority `/admin` router applies Authelia if current upstream behavior supports this safely;
- [ ] restart policy appropriate for a persistent service;
- [ ] Remux added to the common Compose network;
- [ ] Remux profile added without modifying unrelated upstream services;
- [ ] internal AIOStreams URL uses Docker service discovery;
- [ ] no client-visible response leaks internal Docker-only addresses.

Gate: Remux survives recreate/reboot, its API/UI routes behave correctly, and the relevant K3s-era functional contract is preserved.

### Phase 6 - Authentication validation

- [ ] create/restore intended Authelia user configuration locally;
- [ ] validate one-factor/two-factor behavior as intended;
- [ ] verify `/admin` unauthenticated request is challenged;
- [ ] verify authenticated `/admin` access works;
- [ ] verify API, WebSocket, Jellyfin client, and playback paths are not accidentally protected by browser-oriented forward auth;
- [ ] verify logout/session behavior;
- [ ] compare authentication boundaries against the old deployment and document intentional differences.

Gate: authentication adds protection without breaking clients.

### Phase 7 - LAN/local end-to-end validation

Before any Internet forwarding change, validate from real clients on local/LAN paths where possible:

- [ ] AIOStreams configuration and addon behavior;
- [ ] Remux admin login;
- [ ] Jellyfin-compatible client login;
- [ ] library browse/search;
- [ ] stream selection;
- [ ] playback start;
- [ ] seek/resume;
- [ ] WebSocket/session behavior;
- [ ] persistence after container restart;
- [ ] persistence after LXC reboot;
- [ ] logs contain no recurring fatal/error loop;
- [ ] resource usage is reasonable;
- [ ] parity matrix has no unexplained critical gap.

Gate: new stack is technically ready for operator review, but **Internet forwarding remains unchanged**.

### Phase 8 - Operator validation boundary

STOP here and present a sanitized evidence report.

The operator reviews:

- architecture/diff;
- parity results;
- local/LAN UAT;
- exposure model;
- TLS design;
- rollback plan;
- remaining risks.

Only after explicit operator approval may the executor proceed to public forwarding/cutover work.

This approval is not implied by successful tests.

### Phase 9 - DNS, TLS and Internet forwarding

After explicit operator authorization, select and validate one TLS/exposure model.

The previous stack demonstrated that the public port is an edge concern and may differ from Traefik's internal 443. Preserve that separation where useful.

Possible models include:

**Standard:** public TCP 80/443 to Traefik using an appropriate certificate mechanism.

**Nonstandard public HTTPS port:** keep the public-port mapping separate from application/container ports and use a certificate method that does not incorrectly assume TLS-ALPN validation on that nonstandard external port. DNS-01 is an option if appropriate.

Then, and only then:

- [ ] configure/adjust approved DNS records if required;
- [ ] configure approved NAT/firewall/forwarding only for required ports;
- [ ] obtain/validate certificates;
- [ ] confirm independent external reachability;
- [ ] confirm source IP / trusted proxy handling;
- [ ] keep administrative surfaces protected;
- [ ] confirm Jellyfin/API/WebSocket/playback behavior externally;
- [ ] confirm no unintended service/host port is Internet reachable.

Gate: external smoke tests pass without exposing unintended ports/services.

### Phase 10 - Update strategy

Do not enable blind production auto-update until the baseline is stable.

Preserve the risk distinction established by the previous project:

- AIOStreams may follow a faster controlled update path once recovery is proven;
- Remux remains conservative/version-reviewed until migration and compatibility behavior is repeatedly proven;
- stateful/core infrastructure updates require rollback evidence.

Evaluate updater capabilities supplied by the Viren070 template and choose one policy:

1. notify-only / manual controlled updates; or
2. automatic updates only for explicitly opted-in containers with a known previous image/digest and bounded validation.

Gate: documented update and rollback process.

### Phase 11 - Cutover and rollback

Before cutover:

- [ ] export/backup required state from the existing stack;
- [ ] verify backup restore path for new persistent data;
- [ ] record previous DNS/NAT/forwarding state locally;
- [ ] keep old deployment intact;
- [ ] record current working image tags/digests for the Docker deployment.

Cutover:

- [ ] redirect approved production DNS/NAT/forwarding to the new LXC;
- [ ] execute final external smoke tests;
- [ ] observe logs and resource usage;
- [ ] keep rollback available until the new stack is proven stable.

Rollback means restoring previous DNS/NAT/forwarding and using the still-intact previous deployment. Destructive cleanup is a separate later phase.

### Phase 12 - Portability proof / VM runbook

After the Docker baseline is stable, maintain enough documentation/scripts to reproduce it on a normal Debian VM with Docker and no K3s.

- [ ] inventory all host-specific assumptions;
- [ ] ensure real configuration can be restored independently of LXC identity;
- [ ] document application-data backup/restore;
- [ ] document VM Docker/Compose prerequisites;
- [ ] document file ownership/permissions restoration;
- [ ] document how to restore `/opt/docker` configuration and persistent data;
- [ ] document validation before switching forwarding from LXC to VM;
- [ ] ensure public forwarding remains an operator-controlled final step.

Gate: no critical application requirement is LXC-specific, or any unavoidable exception is documented.

### Phase 13 - Decommission old K3s stack

Only after an explicit acceptance period and separate operator authorization:

- [ ] archive required configuration/state;
- [ ] preserve historical repository/validation evidence;
- [ ] remove obsolete K3s workload/resources if desired;
- [ ] remove obsolete DNS/NAT entries if desired;
- [ ] update repository documentation to `production` status.

Do not treat decommissioning as part of initial cutover.

## Validation commands

Exact commands may evolve, but every deployment should include at least:

```bash
docker compose config
docker compose ps
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker network inspect aio_network
ss -lntup
```

Application-specific HTTP/API checks should be added to `scripts/validate.sh` once the final routes are implemented.

The validation suite should contain explicit parity checks derived from `PARITY.md`, not only Docker health checks.

## Non-goals

For the initial migration, do not:

- introduce Kubernetes/K3s inside the new LXC or future Docker VM;
- run multiple reverse proxies for the same stack;
- duplicate the Viren070 template into a large independently maintained fork;
- expose Docker's TCP API;
- publish database/Redis ports;
- commit populated environment files;
- commit real host addresses or production domains;
- modify the existing K3s stack during comparison;
- enable Internet forwarding to the new LXC before explicit operator approval;
- remove the existing production deployment before UAT and rollback validation are complete.
