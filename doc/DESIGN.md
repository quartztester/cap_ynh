# cap — packaging design

cap is a proof-of-work captcha: a Bun/Elysia JS server that keeps all its state in redis. The traffic is split in two, anonymous visitors solving challenges and admins using the dashboard, and that split drives most of the packaging choices.

Anything not mentioned here is standard YunoHost boilerplate identical in most packages.

## Lifecycle

- **Install:** ask for the [admin key](../manifest.toml#L46-L51) (min 12, checked at [install L23-L26](../scripts/install#L23-L26)), store the secrets in app settings, download the pinned sources, move `standalone/` into place, run bun install offline, render the redis and app configs and units, then start and [wait on /health before declaring success](../scripts/_common.sh#L4-L18), so a broken install fails instead of half-passing.
- **Upgrade:** swap sources, [re-render all config from current settings](../scripts/upgrade#L64-L93), restart, and wait on /health again. Settings and `$data_dir` survive untouched.
- **Backup/restore:** [redis BGSAVE, then copy](../scripts/backup#L27-L42). Restore [re-renders configs from settings](../scripts/restore#L39-L59) instead of trusting archived copies.

## Decisions

- **Source:** [monorepo tarball + pinned bun binary, per-arch](../manifest.toml#L60-L68). [`standalone/` is moved by hand](../scripts/_common.sh#L20-L39), because `in_subdir=2` would flatten the tree and clobber `standalone/package.json`.
- **Runtime:** plain JS, no compile step. Deps install [offline from bun.lock](../scripts/install#L68-L76). amd64 and arm64.
- **Storage:** cap keeps its state in a [private per-app redis](../scripts/install#L86-L101) with its own config, port and dump dir, so keys never mix with other apps and the backup is atomic with the app. [RDB snapshotting with noeviction](../conf/redis.conf#L17-L20), because lost keys or sessions break live captcha verifications.
- **Auth:** the [main URL is public](../manifest.toml#L41-L45), since visitors must solve challenges anonymously. [/server, /auth and /public are portal-gated by regex](../manifest.toml#L86-L92), admins only. nginx only proxies and [overwrites X-Forwarded-For](../conf/nginx.conf#L3) because the rate limiting reads it. Both ports are [loopback-bound](../manifest.toml#L94-L97).
- **Path:** root-only. The app issues root-absolute redirects, so install [refuses sub-paths](../scripts/install#L16-L21).
- **Sandboxing:** the full hardening set on both units, with [one named exception](#dont-break).
- **Backup:** everything, and redis gets the [explicit BGSAVE](../scripts/backup#L27-L42) because the on-disk dump can lag 60 s.

## Don't break

- [ProtectHome=no on the app unit](../conf/systemd.service#L19-L25). bun caches under `$HOME` and the data dir lives under `/home/yunohost.app`.
- [Portal regex keeps groups non-capturing](../manifest.toml#L86-L92). Capture groups shorten ssowat's longest match below `/` and silently drop the gate.
- [Restore permission fixups](../scripts/restore#L24-L37). `ynh_restore` chmod-400s the vhost conf and app tree.
- Don't remove the [/health gate on every start path](../scripts/_common.sh#L4-L18), or half-broken installs will pass CI.
