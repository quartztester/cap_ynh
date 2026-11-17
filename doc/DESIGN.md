# How this package works

Two parts: first a walkthrough of what actually happens during install,
upgrade, and backup; then the non-obvious choices explained. Anything not
mentioned is standard YunoHost boilerplate identical in most packages.

## Install, in order

1. The installer asks for domain, path, and an [admin key](../manifest.toml#L46-L51) (min 12 chars, checked in [scripts/install L23-L26](../scripts/install#L23-L26)). Path must be `/` or install [stops immediately](../scripts/install#L16-L21).
2. The redis password is [generated and stored in app settings](../scripts/install#L32-L37) along with the admin key. Settings are the source of truth: every later re-render reads from them, never from the archived env file.
3. The monorepo tarball and the [pinned bun binary](../scripts/install#L55-L62) download into `$install_dir`; [cap_place_standalone](../scripts/_common.sh#L20-L39) moves the `standalone/` subdir up into place, keeping `node_modules`, `bin/`, `env` from a previous version.
4. `bun install --frozen-lockfile` installs JS deps [offline from the lockfile](../scripts/install#L68-L76).
5. The private redis renders [its own config](../scripts/install#L86-L94) and gets [its own systemd unit](../conf/redis.service); install [pings it until PONG](../scripts/install#L103-L111).
6. The app's [env file](../scripts/install#L117-L121) (admin key + redis password, chmod 600) and [systemd unit](../conf/systemd.service) render, then the app starts and install [waits for /health to report ok](../scripts/_common.sh#L4-L18) before declaring success.
7. Nginx is configured last ([6 locations](../conf/nginx.conf)), the only public surface: captcha endpoints open to the internet, admin paths blocked by the YunoHost portal.

## Upgrade

Stops the app, swaps sources the same way as install, re-renders env/redis configs [from current settings](../scripts/upgrade#L64-L83), restarts redis then app, waits for health again. Nothing else to know: settings and `$data_dir` survive untouched.

## Backup / restore

Backup asks redis to [flush its RDB to disk before the archive copies](../scripts/backup#L27-L42) (the on-disk dump can be 60 s stale). Restore re-renders env/redis.conf from settings instead of trusting archived copies ([restore L39-L59](../scripts/restore#L39-L59)).

# Design decisions

Why the pieces above are built the way they are. Links go to the exact code.

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
