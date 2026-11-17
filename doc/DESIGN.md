# cap — packaging design

Proof-of-work captcha: Bun/Elysia JS server with all state in redis. Its split traffic — anonymous visitors solving challenges vs an admin dashboard — shapes everything below.

Anything not mentioned here is standard YunoHost boilerplate identical in most packages.

## Lifecycle

- **Install:** ask [admin key](../manifest.toml#L46-L51) (min 12, enforced at [install L23-L26](../scripts/install#L23-L26)) → store secrets in app settings → download pinned sources, move `standalone/` into place, bun install offline → render private-redis conf+unit and app env+unit → start and [wait on /health before declaring success](../scripts/_common.sh#L4-L18): a broken install dies loudly.
- **Upgrade:** swap sources, [re-render all config from current settings](../scripts/upgrade#L64-L93), restart, re-gate health. Settings and `$data_dir` survive untouched.
- **Backup/restore:** [redis BGSAVE, then copy](../scripts/backup#L27-L42); restore [re-renders configs from settings](../scripts/restore#L39-L59) instead of trusting archived copies.

## Decisions

- **Source:** [monorepo tarball + pinned bun binary, per-arch](../manifest.toml#L60-L68). [`standalone/` is moved by hand](../scripts/_common.sh#L20-L39) — `in_subdir=2` would flatten the tree and clobber `standalone/package.json`.
- **Runtime:** plain JS, no compile step; deps installed [offline from bun.lock](../scripts/install#L68-L76); amd64+arm64.
- **Storage:** [private per-app redis](../scripts/install#L86-L101) — own config/port/dump, no key mixing with other apps, atomic backup with the app. [RDB snapshotting, noeviction](../conf/redis.conf#L17-L20): lost keys/sessions break live captcha verifications.
- **Auth:** [main URL public](../manifest.toml#L41-L45) — visitors must solve challenges anonymously; [/server /auth /public portal-gated by regex](../manifest.toml#L86-L92), admins only. nginx only proxies and [overwrites X-Forwarded-For](../conf/nginx.conf#L3) (rate limiting reads it). Both ports [loopback-bound](../manifest.toml#L94-L97).
- **Path:** root-only — the app issues root-absolute redirects, so install [refuses sub-paths](../scripts/install#L16-L21).
- **Sandboxing:** full hardening set on both units, [one named exception](#dont-break).
- **Backup:** everything; redis gets the [explicit BGSAVE](../scripts/backup#L27-L42) because the on-disk dump can lag 60 s.

## Don't break

- [ProtectHome=no on the app unit](../conf/systemd.service#L19-L25) — bun caches under `$HOME` and the data dir lives under `/home/yunohost.app`.
- [Portal regex keeps groups non-capturing](../manifest.toml#L86-L92) — capture groups shorten ssowat's longest match below `/` and silently drop the gate.
- [Restore permission fixups](../scripts/restore#L24-L37) — `ynh_restore` chmod-400s the vhost conf and app tree.
- The [/health gate on every start path](../scripts/_common.sh#L4-L18) — removing it lets half-broken installs pass CI.
