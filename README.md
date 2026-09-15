# lxc-remux-stack

Docker-based media stack running initially inside a dedicated Proxmox LXC.

The project replaces the previous K3s deployment with a simpler single-node Docker Compose architecture based on:

- [Viren070/docker-compose-template](https://github.com/Viren070/docker-compose-template) for the common application stack and ingress/authentication services.
- [lostb1t/remux](https://github.com/lostb1t/remux) for the Jellyfin-compatible Remux server.
- Proxmox Community Scripts `ct/docker.sh` for provisioning the initial Docker LXC.

The functional reference is the existing [FabioCamin8/k3s-streaming-stack](https://github.com/FabioCamin8/k3s-streaming-stack). The running K3s node remains online during migration and is treated as a read-only behavior/reference source and rollback environment until the operator explicitly approves cutover. Host addresses and credentials are operational data supplied out of band and are never committed here.

## Target architecture

```text
Proxmox
└── Docker host: initially LXC, optionally Debian VM later
    └── Docker / Compose
        ├── Traefik
        ├── Authelia
        │   ├── PostgreSQL
        │   └── Redis
        ├── AIOStreams
        ├── Remux
        ├── Cloudflare DDNS (optional)
        └── controlled image update service (decision pending)
```

The Viren070 template remains the upstream base for the shared services. Remux
is integrated into the same Compose project and frontend application network
rather than maintained as a second independent stack. Authelia's PostgreSQL and
Redis backends use a separate internal network that is not shared with
AIOStreams or Remux.

The new implementation should preserve the useful contracts already validated in the K3s stack, but it must not mechanically reproduce Kubernetes. See [`docs/PARITY.md`](docs/PARITY.md).

The Compose/application design must also remain portable from the initial LXC to a normal Debian VM running Docker, without reintroducing K3s. See [`docs/PORTABILITY.md`](docs/PORTABILITY.md).

## Current status

The sanitized Compose overlay, bootstrap/operation helpers, pinned upstream
candidates, validation matrix and recovery/portability runbooks are implemented
on the feature branch. Target-LXC provisioning and all runtime/LAN gates remain
pending. No production cutover is represented by this repository.

See:

- [`docs/PLAN.md`](docs/PLAN.md) for the implementation and migration plan.
- [`docs/PARITY.md`](docs/PARITY.md) for the behavioral contract inherited from the previous K3s stack.
- [`docs/PORTABILITY.md`](docs/PORTABILITY.md) for the LXC-to-VM Docker portability contract.
- [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md) for LXC provisioning and first-host checks.
- [`docs/UPSTREAMS.md`](docs/UPSTREAMS.md) for reviewed source/image revisions.
- [`docs/OPERATIONS.md`](docs/OPERATIONS.md) for deployment, backup and rollback.
- [`docs/VALIDATION.md`](docs/VALIDATION.md) for the local/LAN acceptance matrix.
- [`docs/CUTOVER.md`](docs/CUTOVER.md) for the proposed, approval-gated forwarding and rollback sequence.
- [`SECURITY.md`](SECURITY.md) for secret-handling rules.
- [`AGENTS.md`](AGENTS.md) for Codex/subagent operating rules.

## Design principles

- Keep the deployment KISS: one Docker host, one Docker Compose project, one
  frontend application network, and narrowly scoped internal backend networks.
- Keep the Viren070 template structure recognizable so upstream updates remain easy to consume.
- Preserve functional parity with the previous K3s deployment where it matters to clients, security, persistence, TLS, recovery and operations.
- Do not copy Kubernetes-specific complexity when Docker Compose has a simpler equivalent.
- Store configuration-as-code here, but never commit credentials, tokens, private keys, generated Authelia secrets, API keys, populated `.env` files, private addresses or production hostnames.
- Expose only the routes that actually require public access.
- Protect administrative interfaces independently from media/API endpoints so Jellyfin-compatible clients and WebSockets are not broken by forward authentication.
- Validate the new Docker stack completely on local/LAN paths before the operator enables Internet forwarding to the new host.
- Keep the runtime portable to a conventional Debian VM + Docker without K3s.

## Migration boundary

Before operator validation:

```text
existing K3s stack -> remains online and untouched
new Docker LXC     -> build, compare, validate locally/LAN
public forwarding  -> remains on existing state
```

Only after explicit operator approval may public DNS/NAT/forwarding be changed toward the new Docker host. Destructive cleanup of the old K3s environment is a separate later decision.

## Repository state convention

Until cutover, documentation distinguishes between:

- **planned**: intended configuration not yet deployed;
- **validated**: verified inside the new Docker host;
- **production**: receiving the real DNS/NAT traffic.

Do not treat configuration committed here as production-valid unless the corresponding validation is recorded in the plan/checklist.
