# How this package works

Install, upgrade, backup — in the order things happen, with the *why*.
Anything not mentioned here is standard YunoHost boilerplate identical
in most packages.

1. Install asks for an [admin key](../manifest.toml#L46-L51) (min 12 chars, checked in [install L23-L26](../scripts/install#L23-L26)) and refuses any [path other than `/`](../scripts/install#L16-L21) — the app issues root-absolute redirects, so a sub-path install looks fine but the UI is broken.

2. Secrets (admin key, [generated redis password](../scripts/install#L32-L37)) go into app settings, which are the source of truth: the env file and redis.conf are always re-rendered from settings — on upgrade, on restore, never from archived copies ([restore L39-L59](../scripts/restore#L39-L59)).

3. Sources are [pinned per architecture](../manifest.toml#L60-L68): the monorepo tarball plus a bun binary — cap is plain JS, no compile step, works on amd64+arm64. The [standalone/ subdir is moved by hand](../scripts/_common.sh#L20-L39) because `in_subdir=2` would flatten the tree and clobber `standalone/package.json`; the move also preserves `node_modules`, `bin/` and `env` across upgrades.

4. The app's authoritative state (site keys, API keys, rate-limit counters) lives in a [private per-app redis](../scripts/install#L86-L101), not the shared system one — no key mixing with other apps, atomic backup with the app, same reason upstream's compose ships a dedicated valkey. [RDB snapshotting with noeviction](../conf/redis.conf#L17-L20): losing keys on a power cut would break live captcha verifications.

5. Start-up renders the [chmod-600 env file](../scripts/install#L117-L121) and systemd units, then [waits for /health before declaring success](../scripts/_common.sh#L4-L18) — a broken install fails loudly instead of half-working.

6. Auth is split: [the main URL is public](../manifest.toml#L41-L45) because anonymous visitors must solve challenges, while `/server`, `/auth`, `/public` are [portal-gated by regex](../manifest.toml#L86-L92). The regex groups must stay non-capturing or ssowat's longest-match drops the gate. nginx only proxies; it [overwrites X-Forwarded-For](../conf/nginx.conf#L3) because cap's rate limiting reads it. Both ports are loopback-bound, never firewall-allowed ([manifest L94-L97](../manifest.toml#L94-L97)).

## Maintenance notes

- Upgrade is routine: swap sources, re-render configs from settings, restart, wait for health ([upgrade L64-L93](../scripts/upgrade#L64-L93)).
- Backup triggers [redis BGSAVE and waits](../scripts/backup#L27-L42) before copying `$data_dir` — the on-disk dump can lag 60 s and a stale restore would lose freshly created site keys.
- Hardening is the full set on both units with [one named exception](../conf/systemd.service#L19-L25): `ProtectHome=no` because bun caches under `$HOME` and the data dir lives in `/home/yunohost.app`. Don't "fix" it without testing.
