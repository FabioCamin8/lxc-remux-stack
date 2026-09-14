# LXC bootstrap

Status: **planned**

This document describes the sanitized provisioning workflow for the initial dedicated Docker LXC. Real credentials and host-specific values must be supplied only in the local shell and must never be committed.

The LXC is the first Docker host, not an application architecture dependency. The Compose deployment must remain portable to a conventional Debian VM as described in [`PORTABILITY.md`](PORTABILITY.md).

## 1. Provision the Docker LXC

The deployment uses the Proxmox VE Community Scripts Docker LXC installer.

Sanitized command shape:

```bash
mode=generated \
var_hostname='<HOSTNAME>' \
var_ssh='yes' \
var_nesting='1' \
var_pw='<TEMPORARY_ROOT_PASSWORD>' \
var_template_storage='<PROXMOX_TEMPLATE_STORAGE>' \
var_ssh_authorized_key='<SSH_PUBLIC_KEY>' \
var_os='debian' \
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/docker.sh)"
```

Do not save the populated command in this repository or in a shell script tracked by Git.

## 2. Record deployment facts locally

After provisioning, determine and retain locally:

```bash
hostnamectl
cat /etc/os-release
docker version
docker compose version
ip -br addr
ip route
findmnt /
df -h /
free -h
nproc
```

The repository documentation should record only non-sensitive architectural facts and software-version requirements. Do not commit the real LXC IP address, CT ID, SSH key, public endpoint or other infrastructure identifiers.

## 3. Baseline checks

Confirm:

- Debian is the expected release.
- Docker Engine starts automatically.
- Docker Compose v2 is available as `docker compose`.
- the container has working DNS and outbound HTTPS;
- time and timezone are correct;
- SSH public-key authentication works before disabling or rotating any temporary password;
- the root filesystem has adequate free space;
- Docker can create and start a disposable container;
- no unusual LXC-only runtime dependency is introduced merely to make the application stack work.

Suggested validation:

```bash
systemctl is-active docker
docker run --rm hello-world
curl -fsSI https://github.com >/dev/null
```

## 4. Host packages

Install only the small set required for operating the stack:

```bash
apt-get update
apt-get install -y git curl ca-certificates openssl
```

Avoid installing application dependencies directly on the Docker host when they belong inside containers.

## 5. Clone this repository

Recommended working location:

```bash
mkdir -p /opt
cd /opt
git clone https://github.com/FabioCamin8/lxc-remux-stack.git
cd lxc-remux-stack
```

This repository is the deployment wrapper and documentation source. The Viren070 template will be brought in during the implementation phase in a way that preserves a clear upstream relationship.

## 6. Previous K3s reference

The existing K3s streaming node remains online during migration. Its repository is:

```text
https://github.com/FabioCamin8/k3s-streaming-stack
```

The operator may provide its private address/access path separately. Do not record that address in Git.

The old node may be inspected read-only to verify the actual behavior that the Docker replacement must preserve. Do not modify/restart the old stack during bootstrap or comparison without explicit operator authorization.

See [`PARITY.md`](PARITY.md).

## 7. Secrets

Generate and store all real secrets locally. Never place them in Git history.

Examples:

```bash
openssl rand -hex 32
openssl rand -base64 64 | tr -d '=/' | tr -d '\n'; echo
```

Real `.env` files must remain ignored. Only `.env.example` files with placeholders may be committed.

## 8. Internet exposure boundary

Do not change production DNS, NAT, firewall rules, Internet forwarding, or the existing K3s stack at this stage.

The new LXC must first pass the validation gates in [`PLAN.md`](PLAN.md). When local/LAN validation is complete, stop and present evidence to the operator. Internet forwarding to the new LXC is enabled only after explicit operator approval.

## 9. Future VM bootstrap

A later migration to a Debian VM should reuse the same application/deployment contract:

1. provision supported Debian VM;
2. install Docker Engine and Compose v2;
3. clone this repository and the tested Viren070 upstream revision;
4. restore untracked configuration/secrets and persistent data;
5. run `docker compose config`;
6. start and validate services;
7. switch forwarding only after operator validation.

K3s is intentionally not part of that future VM path.
