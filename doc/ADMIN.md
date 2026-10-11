# cap — admin documentation

## Admin key

The instance admin key is stored in YunoHost app settings:

```bash
yunohost app setting cap admin_key
```

It is used to authenticate to the key-management API (`/server/*`) and to
log into the dashboard at `https://<domain>/` (submit via `/auth/login`,
which is portal-gated).

## Portal gating

- `/server/*`, `/auth/*`, `/public/*` → YunoHost portal, `admins` group.
- Everything else (challenge/redeem/siteverify, `/health`, widget assets)
  stays public — this is required for anonymous visitors to solve captchas.

## Services

| Unit | Purpose |
|---|---|
| `cap.service` | Bun HTTP server (nginx → `127.0.0.1:3853`) |
| `cap-redis.service` | Private Redis instance on `127.0.0.1:3854` |

Logs: `journalctl -u cap -f`, `journalctl -u cap-redis -f`.

## Using the captcha on your sites

Create a site key in the dashboard, then follow the upstream guide:
<https://trycap.dev/guide/standalone/usage>.
