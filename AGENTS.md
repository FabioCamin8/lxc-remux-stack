# Agent operating instructions

This repository is public. These instructions apply to Codex and other coding/operations agents working on this project.

## Primary objective

Implement and validate the Docker/LXC Remux stack described in `docs/PLAN.md` while preserving a clean relationship with `Viren070/docker-compose-template`.

## Security rules

1. Never commit or print real passwords, tokens, cookies, API keys, personal email addresses, SSH keys, private IP addresses, public IP addresses, or production domain names.
2. Never copy a populated `.env` file into this repository.
3. Use placeholders in tracked files and real values only in ignored/local runtime files.
4. Treat credentials supplied interactively by the operator as secrets even if they appear in terminal history or prior chat context.
5. Do not put secret values in commit messages, PR descriptions, issue text, test fixtures, screenshots, logs, or documentation.
6. Before every commit, review the complete diff and perform a secret-oriented grep. See `SECURITY.md`.
7. If a secret is discovered in Git history, stop and report it rather than attempting to hide the event with a normal follow-up commit.

## Change discipline

- Read `README.md`, `SECURITY.md`, `docs/BOOTSTRAP.md`, and `docs/PLAN.md` before making changes.
- Inspect the current upstream repositories and documentation before implementing configuration that depends on current behavior.
- Keep changes small and reviewable.
- Prefer adding an overlay or deployment script over copying and modifying large portions of the Viren070 template.
- Pin or record the exact tested upstream revision.
- Do not silently change architecture decisions in `docs/PLAN.md`. If evidence requires a different design, update the decision and explain why in the commit.
- Do not modify unrelated services in the Viren070 template.

## Runtime safety

Until an operator explicitly authorizes production cutover:

- do not modify router/firewall/NAT configuration;
- do not modify public DNS;
- do not stop or remove the existing production K3s deployment;
- do not delete old persistent data;
- do not open Docker's remote TCP API;
- do not expose PostgreSQL, Redis, or Docker socket endpoints publicly;
- do not enable blanket auto-update of the production stack.

The agent may provision and configure the new isolated LXC, clone repositories, create local secrets, start the new Docker services, and perform LAN/local validation.

## LXC provisioning

The operator may provide a Community Scripts `ct/docker.sh` command containing real credentials and an SSH public key.

- Execute it only on the intended Proxmox node.
- Do not save the populated command in this repository.
- Do not echo secret values back in summaries.
- Detect the resulting CT ID rather than hard-coding one.
- Verify the resulting container before proceeding.

See `docs/BOOTSTRAP.md`.

## Upstream template strategy

Runtime target:

```text
/opt/docker                  # Viren070/docker-compose-template
/opt/lxc-remux-stack         # this repository
```

The implementation should provide idempotent scripts or documented commands that:

1. clone/update `/opt/docker` to the tested upstream revision;
2. create local configuration from sanitized examples;
3. apply the project's Remux overlay with a minimal delta;
4. validate `docker compose config`;
5. start services by explicit profiles/phases.

Do not commit generated runtime data from `/opt/docker/data`.

## Remux requirements

Use the current official upstream Remux container image unless the implementation documents a justified exception.

The initial routing goal is:

```text
/admin...       -> Authelia -> Remux
other Remux API/client paths -> Remux without browser forward-auth
```

Verify actual current upstream routes before relying on this model. Functional tests must include Jellyfin-compatible API/client behavior and WebSockets, not only browser access.

## Validation expectations

At each phase:

- render Compose configuration before applying it;
- inspect container health and logs;
- inspect listening host ports;
- verify expected Docker network membership;
- recreate relevant containers to prove persistence;
- record only sanitized findings in tracked documentation.

Do not mark a phase complete merely because containers are `Up`.

## Git workflow

Work on a dedicated feature branch unless the operator explicitly requests direct-to-main changes.

Before commit:

```bash
git status --short
git diff
git diff --cached
```

Commit logical units separately. Push normally. Do not force-push unless explicitly instructed.

## Stop conditions

Stop and report rather than improvising if:

- the provisioning command targets an ambiguous Proxmox host;
- required storage/network resources are missing;
- applying the plan would modify production DNS/NAT/K3s without explicit approval;
- current upstream behavior contradicts the documented security/routing model;
- a credential appears to have been committed;
- an operation would be destructive and rollback has not been established.
