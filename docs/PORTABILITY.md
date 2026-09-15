# Docker host portability contract

Status: **design requirement**

The initial target is a Proxmox LXC because it is lightweight and sufficient for this Docker Compose stack. The deployment must nevertheless remain portable to a conventional Debian VM running Docker, without introducing K3s.

## Portability goal

A future migration should look broadly like:

```text
backup application/config data
        -> provision Debian VM
        -> install Docker + Compose
        -> clone this repository and tested Viren070 upstream revision
        -> restore local configuration/secrets and persistent data
        -> docker compose config
        -> docker compose up -d
        -> validate
        -> move network forwarding after operator approval
```

It should **not** require redesigning the application stack.

## Host-neutral requirements

Tracked configuration and deployment automation should assume only:

- supported Debian Linux host;
- Docker Engine;
- Docker Compose v2;
- systemd;
- normal filesystem bind mounts;
- normal Docker bridge networking;
- outbound DNS/HTTPS;
- required inbound ports when explicitly enabled by the operator.

Avoid dependencies on:

- Kubernetes/K3s;
- LXC-only device mappings;
- Proxmox-specific mount paths inside Compose files;
- host networking unless technically justified and documented;
- hard-coded interface names;
- hard-coded IP addresses;
- hard-coded Proxmox CT IDs or VM IDs;
- Docker Swarm;
- host-local paths that cannot be recreated predictably.

## Filesystem contract

Keep runtime state under predictable paths such as:

```text
/opt/docker/             upstream Viren070 template working tree
/opt/lxc-remux-stack/    this deployment repository
/opt/docker/data/        application persistent data, unless a later documented storage root is selected
```

If large media/cache storage later moves to another filesystem, reference it through a documented configurable absolute path rather than embedding an LXC-specific mount assumption.

## Configuration contract

Real configuration remains local and untracked.

The public repository should contain enough sanitized examples and automation to recreate the deployment on either an LXC or a VM.

Secrets must be portable independently of the host type. Backups must include the secrets required to read existing encrypted application state where applicable.

## Network contract

Container-to-container dependencies use Docker service names. Traefik,
Authelia, AIOStreams, and Remux use the frontend application network;
Authelia, PostgreSQL, and Redis additionally use a separate internal
authentication-backend network. AIOStreams and Remux do not join that backend
network.

Client-visible URLs must use externally valid names/URLs rather than Docker-only service names.

Internet forwarding is an operator-controlled edge concern, not part of application bootstrap. The initial LXC can therefore be fully validated on LAN/local paths before any public NAT/forwarding is changed.

## Validation for future LXC -> VM migration

Before declaring the implementation portable, confirm that no critical runtime requirement depends specifically on LXC.

A future VM migration runbook must validate:

- Docker and Compose versions;
- restored file ownership/permissions;
- persistent databases/state;
- common Docker network;
- Traefik routing;
- TLS/certificate lifecycle;
- Authelia sessions/users as applicable;
- AIOStreams manifest/configuration;
- Remux Jellyfin/API/WebSocket behavior;
- playback/redirect behavior;
- reboot recovery;
- rollback to the old host until forwarding is switched.

The desired end state is one Docker Compose architecture that can run on either a Proxmox LXC or a normal Debian VM. K3s is intentionally not part of that portability path.

The implemented overlay uses only bind mounts below configurable `/opt` roots,
normal bridge networks, Compose profiles, an internal authentication-backend
network, and a Unix Docker socket isolated behind an internal proxy network. It
contains no CT ID, VM ID, device mapping, host interface, host IP, Kubernetes
object, or Proxmox-only mount. The detailed backup/restore and forwarding
rollback sequence is in [`OPERATIONS.md`](OPERATIONS.md).
