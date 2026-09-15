# Proposed Internet cutover and rollback

Status: **proposal only — execution is not authorized**

This runbook deliberately uses placeholders. Real addresses, domains, router
rules, certificate credentials and current forwarding state remain in private
operator records and never enter Git.

## Port model

```text
application containers: 3000 (Docker network only)
Traefik container:       443 (internal HTTPS entrypoint)
Docker host:             8443 by current LAN default
WAN edge:                <WAN_HTTPS_PORT>, selected by the operator
```

The edge rule therefore maps:

```text
TCP <WAN_HTTPS_PORT> -> <NEW_DOCKER_HOST>:<TRAEFIK_HOST_HTTPS_PORT>
```

The two ports may be equal, but do not have to be. No AIOStreams, Remux,
Authelia, PostgreSQL, Redis, Docker API, socket-proxy, SSH, or Proxmox port is
forwarded separately.

## Approval prerequisites

Before requesting authorization:

1. finish every possible local/LAN row in `VALIDATION.md`;
2. prove recreate, backup/restore and LXC reboot recovery;
3. record exact working image digests and private data/config checksums;
4. capture the current router/NAT/firewall/DNS state privately for rollback;
5. confirm the old K3s stack remains healthy and unchanged;
6. choose a certificate path that works with the selected WAN port;
7. obtain explicit operator approval for the concrete edge/DNS changes.

For a nonstandard WAN HTTPS port, do not assume TLS-ALPN validation on WAN
443. Prefer an approved DNS-01 resolver configured with a least-privilege token
stored only in an untracked local secret, or restore a valid certificate/key
through an untracked Traefik file-provider configuration. Certificate issuance
and DNS-provider access are separate authorized operations.

## Proposed cutover

After explicit approval only:

1. take and verify a final private backup of the new stack;
2. confirm new-stack LAN health and old-stack health immediately before change;
3. install/verify the approved public certificate on new Traefik without exposing
   any additional application or management port;
4. change only the approved TCP edge rule to target
   `<NEW_DOCKER_HOST>:<TRAEFIK_HOST_HTTPS_PORT>`;
5. change production DNS only if the approved topology actually requires it;
6. from an independent off-LAN vantage, verify DNS, TCP, TLS/SNI, AIOStreams
   manifest/API, Remux native login/API, both WebSockets, playback, seek/resume,
   redirects, source-IP handling and admin ForwardAuth;
7. inspect new-host ports/logs/health and verify the old K3s stack is still
   intact as rollback;
8. leave decommissioning unstarted until a later, separate authorization.

If any critical check fails, stop forward progress and roll back immediately.

## Exact rollback shape

1. restore the saved router/NAT/firewall target and DNS values byte-for-byte to
   the previous K3s path;
2. verify off-LAN TCP/TLS/application behavior against the old stack;
3. confirm the old K3s workloads and persistent data remain healthy;
4. remove no new-host data and perform no K3s cleanup;
5. retain the failed new-host image/config/data and sanitized diagnostics for
   investigation;
6. if the new stack itself must be reverted, restore its last verified private
   backup and recorded image digests while it is off the production path;
7. repeat LAN validation before requesting another cutover window.

Rollback changes edge routing only. It does not destroy either environment.
