# lxc-remux-stack

Docker-based media stack running inside a dedicated Proxmox LXC.

The project replaces the previous K3s deployment with a simpler single-node Docker Compose architecture based on:

- [Viren070/docker-compose-template](https://github.com/Viren070/docker-compose-template) for the common application stack and ingress/authentication services.
- [lostb1t/remux](https://github.com/lostb1t/remux) for the Jellyfin-compatible Remux server.
- Proxmox Community Scripts `ct/docker.sh` for provisioning the Docker LXC.

## Target architecture

```text
Proxmox
└── LXC: remux
    └── Docker / Compose
        ├── Traefik
        ├── Authelia
        │   ├── PostgreSQL
        │   └── Redis
        ├── AIOStreams
        ├── Remux
        ├── Cloudflare DDNS (optional)
        └── automatic image update service (decision pending)
```

The Viren070 template remains the upstream base for the shared services. Remux will be integrated as an additional app in the same Compose project and Docker network rather than maintained as a second independent stack.

## Current status

Planning and documentation only. No production deployment is represented by this repository yet.

See:

- [`docs/PLAN.md`](docs/PLAN.md) for the implementation and migration plan.
- [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md) for LXC provisioning and first-host checks.
- [`SECURITY.md`](SECURITY.md) for secret-handling rules.

## Design principles

- Keep the deployment KISS: one LXC, one Docker Compose project, one shared network.
- Keep the Viren070 template structure recognizable so upstream updates remain easy to consume.
- Store configuration-as-code here, but never commit credentials, tokens, private keys, generated Authelia secrets, API keys, or populated `.env` files.
- Expose only the routes that actually require public access.
- Protect administrative interfaces independently from media/API endpoints so Jellyfin-compatible clients and WebSockets are not broken by forward authentication.
- Validate the new Docker stack completely before changing DNS/NAT or removing the existing K3s deployment.

## Repository state convention

Until cutover, documentation distinguishes between:

- **planned**: intended configuration not yet deployed;
- **validated**: verified inside the new LXC;
- **production**: receiving the real DNS/NAT traffic.

Do not treat configuration committed here as production-valid unless the corresponding validation is recorded in the plan/checklist.
