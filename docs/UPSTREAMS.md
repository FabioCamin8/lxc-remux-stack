# Tested upstream revisions

Status: **static contract reviewed; runtime validation pending**

| Component | Reviewed source | Reviewed revision | Deployment candidate |
|---|---|---|---|
| Viren template | `Viren070/docker-compose-template` | `25b1b1f29ed33a0e67d28d73a6ad71d728d3800f` | exact detached commit |
| AIOStreams | `Viren070/AIOStreams` | `248d1c4aec817e29a401825dbaff2452c495315f` | `v2.34.0@sha256:d25546200337f633b25fd8bd95ee8dc9ef936573fb80e77cc4e2fe1f120c40ae` |
| Remux | `lostb1t/remux` | stable `v0.31.0`, source `a443b1e2dc12be4251988b00e67a726458c85b75` | `0.31.0@sha256:4406d6a005a3ebe2e8e9f250ebaa07085d808d18051c692790a7cfc099a575e1` |
| Previous stack | `FabioCamin8/k3s-streaming-stack` | merged `main` `6c96e820200a1990e8ef2c01bcbac401e5e0d868` | reference only |

The previous stack also has feature evidence at AIOStreams `c7ed5099764085931bbe39ff5a54a4e3a23a4ee6`, Remux `bad219266f567e5b4ea3ed38f1287635fd8ab282`, and Authelia `17682afb29c4520ecb6e99a6509af8b86a688ac8`. Those branches are comparison evidence, not Docker deployment inputs.

Infrastructure candidates observed from their public registries on 2026-09-14:

| Component | Pinned candidate |
|---|---|
| Authelia | `4.39.20@sha256:1b363e9279e742397966333f364e0876ae02bf5c876de73e83af6d48c57ff51b` |
| PostgreSQL | `17.11-alpine3.24@sha256:18cfe3ef5e6815560c98237d6216d1e5119702fb0f3894c8785dd58b8bbe5d73` |
| Redis | `7.4.11-alpine@sha256:ff02b58f971e7d7d156a1267e283fcbbeee91773b6aa36c49dac28ecfe28eadf` |
| Traefik | `v3.7.13@sha256:f86a2cab1b5c649070c49f883c743dd32d8485a56e3368c5f93b9e91f1e91259` |
| LinuxServer socket-proxy | `latest@sha256:ba211325155c463a1a6e6a038c928f21447a8e60ce02ecf41302047974097e84` |

All image digests in this document are registry observations. They become tested deployment facts only after the target LXC pulls them and the runtime validation matrix passes.

## Why the overlay changes the template

- AIOStreams keeps native authentication. The template's hostname-wide `authelia@docker` middleware is removed because it can redirect machine manifest/API/stream requests to a browser login.
- Remux receives two routers. Only the higher-priority administrative router uses ForwardAuth; it covers `/admin` plus repeated `/emby` compatibility prefixes that Remux strips before routing. `/web`, `/jellyfin`, `/websocket`, `/socket`, native login, APIs, and playback remain Remux-native.
- Traefik publishes only the operator-selected HTTP/HTTPS binds. The template's DNS-over-TLS port is removed.
- Traefik uses a read-only, allowlisted Docker socket proxy on a separate internal network instead of mounting the Docker socket directly.
- Authelia PostgreSQL uses a generated runtime password rather than the template default.
- Authelia PostgreSQL and Redis are isolated on an internal backend network;
  AIOStreams and Remux cannot reach that network.
- Watchtower and WUD remain disabled. Updates are manual and digest-recorded.
