# Operations and recovery

Status: **implementation ready; runtime proof pending**

## Bootstrap

The runtime host must provide Debian, Docker Engine, Docker Compose v2 with `!override` support (v2.24.4 or newer), Git, OpenSSL, Python 3, `curl`, and `ss`.

```bash
git clone https://github.com/FabioCamin8/lxc-remux-stack.git /opt/lxc-remux-stack
cd /opt/lxc-remux-stack
git switch feat/bootstrap-docker-stack
./scripts/bootstrap.sh
```

`bootstrap.sh` checks out the tested Viren revision, creates protected runtime files, records the actual configured absolute paths in the untracked `stack.env`, generates cryptographic secrets, copies the reviewed Authelia configuration into that untracked runtime directory, assigns it to the configured Authelia UID/GID, and creates persistent directories. It never invents operator hostnames or user credentials. Replace every remaining `<...>` marker before rendering Compose.

Select an unused private Docker subnet for `DOCKER_NETWORK_CIDR` after checking
the host routes and existing Docker networks. The same value is interpolated
into AIOStreams `TRUSTED_IPS`, so forwarded client addresses are accepted only
from this stack's reverse-proxy network. Never copy the selected subnet into
public validation evidence.

Generate the Authelia password hash inside the pinned Authelia image and paste only the hash into the untracked user file:

```bash
docker run --rm -it ghcr.io/authelia/authelia:4.39.20 authelia crypto hash generate argon2
```

Then:

```bash
./scripts/stack.sh config
./scripts/stack.sh pull
./scripts/stack.sh up
./scripts/validate.sh
```

`stack.sh config` validates the complete Compose model but prints only a safe
service/image/network/port-count summary. It deliberately omits resolved
environment values, labels, hostnames, and bind sources so secrets and local
topology do not spill into terminal or CI logs.

LAN validation uses the configured hostnames and the selected host HTTPS bind. It does not change DNS, router NAT, firewall rules, or Internet forwarding. Before cutover, Traefik may use its generated default certificate; clients must not treat that as public TLS acceptance.

## AIOStreams and Remux integration

After native Remux administrator setup, add AIOStreams as a Stremio addon using the internal manifest URL:

```text
http://aiostreams:3000/stremio/manifest.json
```

Use the actual configured-manifest path when AIOStreams requires its UUID/encrypted password. Keep Remux `httpRedirectStream` disabled until the redirect matrix proves that no Docker-only/private address can become client-visible. Current Remux also rewrites detected internal addon URLs to the manifest origin, but runtime proof is still required.

## Manual update policy

Do not enable Watchtower. For one reviewed component at a time:

1. record current `docker image inspect` IDs and Compose image references;
2. run `scripts/backup.sh <NEW_ABSOLUTE_BACKUP_DIRECTORY>`;
3. verify `SHA256SUMS` from the backup directory;
4. edit only the image reference in untracked `runtime/stack.env`;
5. run `scripts/stack.sh config` and inspect the rendered diff;
6. pull and recreate only the selected service;
7. run structural and application-specific validation;
8. roll back to the recorded image reference and restore data if migrations are incompatible.

AIOStreams may move faster after restore proof. Remux remains pinned to reviewed stable releases. Authelia, PostgreSQL, Redis, Traefik, and the socket proxy are stateful/core infrastructure and require a separate rollback window.

## Backup and restore

`scripts/backup.sh` captures the configured `DOCKER_DATA_DIR`, the upstream `.env`, the configured untracked runtime directory, exact Viren commit, image inventory, and checksums. The data and runtime archives are rooted at the contents of those configured directories, so restore them into the corresponding configured destinations. It refuses a destination nested below the data or runtime source trees and restarts only stateful services that were running before the backup. The output contains secrets and must stay private with mode `0600` files.

The backup destination's immediate parent must already exist, be expressed as
its canonical path without symlinks, be owned by the invoking user, and not be
writable by group or others. Create a private backup parent first (for example,
mode `0700`), then pass a new child directory to `backup.sh`. This prevents a
less-privileged local process from redirecting secret-bearing backup output.

Restore is deliberately documented rather than automated until runtime ownership and database-consistency tests are complete:

1. keep the old host online and forwarding unchanged;
2. stop only the new Compose project;
3. verify the backup checksums;
4. move the failed new-host data aside to a timestamped private path;
5. restore data, upstream `.env`, and runtime archives with numeric ownership/xattrs/ACLs;
6. restore the recorded image references and exact Viren commit;
7. render Compose, start locally, and rerun the complete validation matrix;
8. change forwarding only after operator approval.

## LXC to Debian VM

The application layer has no CT ID, Proxmox mount, interface name, host IP, K3s, CNI, or LXC device dependency. Migration is:

```text
private verified backup
-> provision supported Debian VM
-> install Docker Engine and Compose v2
-> clone wrapper and exact Viren revision
-> restore runtime secrets/config/data and ownership
-> render/start/validate locally
-> operator approves forwarding move
```

Rollback keeps forwarding on the previous host, or restores it to that host if a separately authorized cutover has already occurred.

The exact sanitized edge-change and rollback proposal is in
[`CUTOVER.md`](CUTOVER.md). It is a proposal, not execution authorization.
