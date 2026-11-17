# Design decisions

Why this package is structured the way it is. Links go to the exact code.

## Bun runtime instead of Node or Docker

- cap is a plain Bun/Elysia JS app — no compile step. The package downloads a [pinned bun binary per architecture](../manifest.toml#L60-L68) into `$install_dir/bin` rather than relying on apt Node or upstream's Docker image. Update URLs + sha256 + version together ([manifest comment](../manifest.toml#L61)).
- JS deps install [offline from bun.lock with --frozen-lockfile](../scripts/install#L74-L75); exact versions, nothing resolves from the network at install. `HOME` points inside `$install_dir` because the system user has no writable home.
- Works on [amd64 and arm64](../manifest.toml#L25) (bun ships both).

## Monorepo: hand-move `standalone/`, not `in_subdir=2`

- Upstream is a monorepo; the package needs its `standalone/` subdir. [in_subdir=1 keeps the structure](../manifest.toml#L55-L58) and [cap_place_standalone moves it up by hand](../scripts/_common.sh#L20-L23). `in_subdir=2` would flatten every second-level dir and clobber `standalone/package.json`.
- The move preserves upgrade-survivors in `$install_dir`: `node_modules`, `.bun-cache`, `bin/`, `env`, `redis.conf`.

## Private redis instance, not the shared system redis

- cap keeps its authoritative state (site keys, hashed secrets, API keys, rate-limit counters) in redis. The package runs a [dedicated per-app instance](../scripts/install#L86-L101) with [its own config, port, password and dump dir](../conf/redis.conf#L1-L21) — no key mixing with other apps, and it can be backed up/restored atomically with the app. Matches upstream's own compose stack, which ships a dedicated valkey container.
- [RDB snapshotting with noeviction](../conf/redis.conf#L17-L20): losing keys/sessions on a power cut would break live captcha verifications.
- The redis password is [generated at install and never printed](../scripts/install#L33-L36); secrets live only in app settings and the [chmod-600 env file](../scripts/install#L119-L121).

## Split auth: public captcha endpoints, portal-gated admin

- The app has no login for visitors — anonymous site visitors must fetch and solve challenges. So the [main permission is public (`visitors`)](../manifest.toml#L41-L45) and the admin surface (`/server`, `/auth`, `/public`) is [gated by a portal regex permission](../manifest.toml#L86-L92), admins-only.
- The regex groups must stay non-capturing — ssowat keeps the longest match and captures would shorten it below `/` and lose the gate ([comment](../manifest.toml#L86)). Regex URLs can't render a portal tile, so `show_tile = false`; the public tile opens the gated dashboard anyway.
- nginx does no auth, only proxying, and overwrites `X-Forwarded-For` with the real IP — cap's rate limiting depends on it ([nginx.conf L3](../conf/nginx.conf#L3)).
- Both ports (app + redis) are [loopback-bound, never firewall-allowed](../manifest.toml#L94-L97).

## Domain root only (`path = /`)

- cap issues root-absolute redirects (`/login`, `/share`) that escape any subpath, so install [refuses non-root paths outright](../scripts/install#L16-L21); the CI subdir test is [excluded to match](../tests.toml#L6-L8).

## Backup snapshots redis before copying

- The live state is in redis memory; the on-disk RDB can lag [up to 60 s](../conf/redis.conf#L17). Backup therefore [triggers BGSAVE and waits for it](../scripts/backup#L27-L42) before the archive copies `$data_dir` — otherwise a restore loses the site keys created since the last snapshot.

## Hardening: strict, with one named exception

- Both units run the [full hardening set](../conf/systemd.service#L19-L32) (no capabilities, syscall denylist). Exception: `ProtectHome=no` on the app unit — bun touches `$HOME` for its cache and the data dir lives under `/home/yunohost.app`. The redis unit keeps `ProtectHome=read-only` with a single `ReadWritePaths`.
- Install and restore [wait on /health before declaring success](../scripts/_common.sh#L4-L18) (app and redis), so a broken install fails loudly instead of half-working.
- `skip_orphan_backup_alert` is [set on install](../scripts/install#L176): the bun binary and `.repo`-derived paths would otherwise trip YunoHost's file-integrity warnings after upgrades.
