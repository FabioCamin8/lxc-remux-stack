# Agent operating instructions

This repository is public. These instructions apply to Codex and other coding/operations agents working on this project.

## Primary objective

Implement and validate the Docker/LXC Remux stack described in `docs/PLAN.md` while preserving a clean relationship with `Viren070/docker-compose-template`, matching the useful functional behavior of `FabioCamin8/k3s-streaming-stack`, and keeping the resulting Compose deployment portable to a normal Debian VM without K3s.

Read before changing anything:

- `README.md`
- `SECURITY.md`
- `docs/BOOTSTRAP.md`
- `docs/PLAN.md`
- `docs/PARITY.md`
- `docs/PORTABILITY.md`

## Execution/orchestration model

The primary executor is **Codex Sol**. It owns the plan, mutations, runtime changes, commits, integration, final verification, and report.

Parallel work is encouraged when useful. Codex Sol may spawn **Luna agents at xhigh effort** for independent tasks such as:

- reading and comparing the old K3s repository;
- inspecting current upstream repositories/documentation;
- deriving a parity checklist;
- reviewing Remux/AIOStreams route contracts;
- reviewing security exposure and secret hygiene;
- designing validation matrices;
- checking Docker/LXC/VM portability;
- reviewing diffs or test evidence.

Parallelization rules:

1. Codex Sol remains the single execution authority.
2. Luna/xhigh agents should normally perform research, audit, analysis, or clearly partitioned repository work.
3. Do not allow two agents to mutate the same file, runtime object, Compose project, or Proxmox resource concurrently.
4. Runtime/provisioning/destructive commands are executed by Codex Sol unless a task has been explicitly isolated and delegated safely.
5. Sol must review and integrate subagent findings rather than accepting them blindly.
6. Each parallel task should have a narrow goal and return evidence/paths/commands, not vague recommendations.
7. Security and production stop boundaries apply equally to all subagents.

Use parallelism to reduce wall-clock work, not to reduce verification quality.

## Previous K3s environment

The existing `k3s-streaming-stack` is both a historical source of truth and a live comparison environment during migration.

Repository:

`https://github.com/FabioCamin8/k3s-streaming-stack`

The operator may provide the private address/access path of the running `k3s01` node out of band. Treat that address and all credentials as sensitive operational data and never write them into this public repository.

When access is available, the old node may be inspected **read-only** to establish actual runtime behavior, versions, routes, persistence boundaries and workarounds. Do not restart, modify, redeploy, patch, delete or otherwise change the old K3s environment without explicit operator authorization.

Do not translate Kubernetes resources literally. Preserve functional contracts, then implement the simplest Docker equivalent. See `docs/PARITY.md`.

## Security rules

1. Never commit or print real passwords, tokens, cookies, API keys, personal email addresses, SSH keys, private IP addresses, public IP addresses, or production domain names.
2. Never copy a populated `.env` file into this repository.
3. Use placeholders in tracked files and real values only in ignored/local runtime files.
4. Treat credentials supplied interactively by the operator as secrets even if they appear in terminal history or prior chat context.
5. Do not put secret values in commit messages, PR descriptions, issue text, test fixtures, screenshots, logs, or documentation.
6. Before every commit, review the complete diff and perform a secret-oriented grep. See `SECURITY.md`.
7. If a secret is discovered in Git history, stop and report it rather than attempting to hide the event with a normal follow-up commit.

## Change discipline

- Inspect the current upstream repositories and documentation before implementing configuration that depends on current behavior.
- Keep changes small and reviewable.
- Prefer adding an overlay or deployment script over copying and modifying large portions of the Viren070 template.
- Pin or record the exact tested upstream revision.
- Do not silently change architecture decisions in `docs/PLAN.md`. If evidence requires a different design, update the decision and explain why in the commit.
- Do not modify unrelated services in the Viren070 template.
- Track intentional differences from the previous K3s implementation in `docs/PARITY.md` or a validation report.
- Avoid LXC-only assumptions in Compose/configuration unless unavoidable and documented. See `docs/PORTABILITY.md`.

## Runtime safety

Until an operator explicitly authorizes production cutover:

- do not modify router/firewall/NAT configuration;
- do not modify public DNS;
- do not stop, restart, patch or remove the existing production K3s deployment;
- do not delete old persistent data;
- do not open Docker's remote TCP API;
- do not expose PostgreSQL, Redis, or Docker socket endpoints publicly;
- do not enable blanket auto-update of the production stack;
- do not forward Internet traffic to the new LXC.

The agent may provision and configure the new isolated LXC, clone repositories, create local secrets, start the new Docker services, perform read-only comparison with the old stack, and perform LAN/local validation.

After the new stack is validated, STOP and request/await operator approval before changing Internet forwarding. The operator will explicitly authorize that stage.

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

Also preserve the previous stack invariant that a client-visible redirect must never expose an internal-only service address such as a Kubernetes service name, Docker service name, or unreachable private backend.

## Host portability

The first runtime is an LXC, but the Compose project must be reusable on a conventional Debian VM with Docker.

Do not make the application design depend on:

- K3s/Kubernetes;
- Proxmox CT IDs;
- LXC-only device mappings;
- hard-coded interface names or host IPs;
- an LXC-specific filesystem path that cannot be configured on a VM.

A future LXC -> VM move should primarily be provisioning + restore + Compose validation, not an application rearchitecture.

## Validation expectations

At each phase:

- render Compose configuration before applying it;
- inspect container health and logs;
- inspect listening host ports;
- verify expected Docker network membership;
- recreate relevant containers to prove persistence;
- compare relevant behavior with the previous K3s environment;
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
- an operation would be destructive and rollback has not been established;
- local/LAN validation is complete and the next step would enable Internet forwarding to the new Docker host.
