# Implementation and migration plan

Status: **planning**

## Goal

Deploy the Remux media stack in one dedicated Proxmox LXC using Docker Compose, with the Viren070 Docker Compose template providing shared infrastructure and supported media services, and Remux added as a small local extension.

The migration must be reversible until final cutover. Existing production services must not be modified or removed until the new stack passes all functional gates.

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

On the LXC, the runtime layout will be:

```text
/opt/docker/                     # Viren070 template working tree
/opt/lxc-remux-stack/            # this repository
```

Local automation will:

1. clone or update the Viren070 template in `/opt/docker`;
2. pin/record the tested upstream revision;
3. apply the small Remux overlay and sanitized configuration templates;
4. keep populated `.env` files only on the LXC;
5. validate the rendered Compose model before starting containers.

This keeps the upstream template easy to update while making the deployment-specific delta reviewable.

## Target services

Initial target:

| Component | Source | Purpose | Initial exposure |
|---|---|---|---|
| Traefik | Viren070 template | reverse proxy / TLS | public 80/443 when cut over |
| Authelia | Viren070 template | protection for administrative UIs | via Traefik |
| Authelia PostgreSQL | Viren070 template | Authelia storage | internal only |
| Authelia Redis | Viren070 template | Authelia session/cache | internal only |
| AIOStreams | Viren070 template | Stremio aggregation | via Traefik |
| Remux | local overlay using upstream image | Jellyfin-compatible media server | via Traefik |
| Cloudflare DDNS | Viren070 template, optional | DNS record maintenance | outbound only |
| image updater | Viren070 template | controlled container updates | internal only |

Additional Viren070 services are out of scope until the minimal stack is validated.

## Remux routing model

Remux serves both administrative/browser surfaces and Jellyfin-compatible client/API traffic. Forward authentication must therefore not be blindly applied to the entire hostname.

Planned routing:

```text
/admin...       -> Authelia -> Remux
all other paths -> Remux directly
```

The implementation must explicitly verify:

- `/admin` protection;
- Jellyfin-compatible API authentication;
- `/web` and `/jellyfin` behavior;
- WebSocket endpoints;
- playback from a real client;
- no Authelia redirect injected into media/API responses.

If Remux upstream changes its path model, routing must be re-evaluated before deployment.

## Phases

### Phase 0 - Repository baseline

- [x] initialize public repository documentation;
- [x] define secret-handling policy;
- [x] document sanitized LXC provisioning;
- [ ] add Codex/agent operating instructions;
- [ ] add example configuration and Remux overlay;
- [ ] add validation scripts.

Gate: repository contains no operational secrets or personal infrastructure values.

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
- [ ] ensure the common Docker network renders correctly.

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
- [ ] no unexpected ports listening on the LXC host;
- [ ] Traefik discovers only explicitly enabled services.

Do not change production DNS/NAT yet.

Gate: local/LAN requests to the reverse proxy behave as designed.

### Phase 4 - Deploy AIOStreams

- [ ] configure a persistent data directory;
- [ ] generate AIOStreams secret locally;
- [ ] start the upstream Viren070 AIOStreams profile;
- [ ] verify health/logs;
- [ ] verify configuration page behavior;
- [ ] verify addon manifest/API behavior;
- [ ] verify persistence across container recreation.

Gate: AIOStreams works through the new Traefik instance without production cutover.

### Phase 5 - Add Remux overlay

Create `overlay/apps/remux/compose.yaml` based on the current official `ghcr.io/lostb1t/remux` image and upstream runtime requirements.

Requirements:

- [ ] persistent `/data` bind mount;
- [ ] no direct public host port unless specifically needed for isolated testing;
- [ ] Traefik service points to Remux internal port;
- [ ] main router remains usable by Jellyfin-compatible clients;
- [ ] separate high-priority `/admin` router applies Authelia;
- [ ] restart policy appropriate for a persistent service;
- [ ] Remux added to the common Compose network;
- [ ] Remux profile added without modifying unrelated upstream services.

Gate: Remux survives recreate/reboot and its API/UI routes behave correctly.

### Phase 6 - Authentication validation

- [ ] create/restore intended Authelia user configuration locally;
- [ ] validate one-factor/two-factor behavior as intended;
- [ ] verify `/admin` unauthenticated request is challenged;
- [ ] verify authenticated `/admin` access works;
- [ ] verify API, WebSocket, Jellyfin client, and playback paths are not accidentally protected by browser-oriented forward auth;
- [ ] verify logout/session behavior.

Gate: authentication adds protection without breaking clients.

### Phase 7 - DNS, TLS and external reachability

Decide and document one TLS model before cutover:

**Preferred:** standard public TCP 80/443 to Traefik with the template's supported ACME path.

If a nonstandard external HTTPS port is required, explicitly redesign certificate issuance (for example DNS-01) rather than assuming TLS-ALPN validation works on a nonstandard public port.

Then:

- [ ] configure DNS records;
- [ ] configure NAT/firewall only for required ports;
- [ ] obtain valid certificates;
- [ ] confirm external reachability;
- [ ] confirm source IP / trusted proxy handling;
- [ ] keep administrative surfaces protected.

Gate: external smoke tests pass without exposing unintended ports/services.

### Phase 8 - End-to-end UAT

From real clients:

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
- [ ] logs contain no recurring fatal/error loop.

Gate: all required user journeys pass.

### Phase 9 - Update strategy

Do not enable blind production auto-update until the baseline is stable.

Evaluate the updater already supplied by the Viren070 template and choose one policy:

1. notify-only / manual controlled updates; or
2. automatic updates only for explicitly opted-in containers.

Avoid automatically updating stateful/core infrastructure without a rollback plan.

Gate: documented update and rollback process.

### Phase 10 - Cutover and rollback

Before cutover:

- [ ] export/backup required state from the existing stack;
- [ ] verify backup restore path for new persistent data;
- [ ] record previous DNS/NAT state locally;
- [ ] keep old deployment intact but quiescent where possible.

Cutover:

- [ ] redirect production DNS/NAT to the new LXC;
- [ ] execute final external smoke tests;
- [ ] observe logs and resource usage;
- [ ] keep rollback available until the new stack is proven stable.

Rollback means restoring previous DNS/NAT and re-enabling the previous deployment. Destructive cleanup is a separate later phase.

### Phase 11 - Decommission old stack

Only after an explicit acceptance period:

- [ ] archive required configuration/state;
- [ ] remove obsolete K3s workload/resources;
- [ ] remove obsolete DNS/NAT entries;
- [ ] update repository documentation to `production` status.

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

## Non-goals

For the initial migration, do not:

- introduce Kubernetes/K3s inside the new LXC;
- run multiple reverse proxies for the same stack;
- duplicate the Viren070 template into a large independently maintained fork;
- expose Docker's TCP API;
- publish database/Redis ports;
- commit populated environment files;
- remove the existing production deployment before UAT and rollback validation are complete.
