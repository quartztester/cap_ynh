# cap for YunoHost

Privacy-first self-hosted captcha: proof-of-work challenges, no puzzles, no
tracking. Visitors solve a small proof-of-work in their browser; no personal
data is collected or stored.

**Shipped version:** 3.1.13

## Features

- Proof-of-work challenges (SHA-3 based), no third-party scripts or cookies
- Widget + server API for your own sites (`/<siteKey>/challenge`,
  `/<siteKey>/redeem`, `/siteverify`)
- Admin dashboard for key management, gated by the YunoHost portal
- Private per-app Redis instance (loopback only, never exposed)

## YunoHost integration

- Admin surface (`/server/*`, `/auth/*`, `/public/*`) is gated by the YunoHost
  portal (`admins` group). The captcha endpoints stay public so anonymous
  visitors can solve challenges.
- The admin key can be read after install with:
  `yunohost app setting cap admin_key`
- No LDAP/SSO user provisioning: the dashboard authenticates with the
  instance admin key.

## Links

- Upstream: <https://github.com/tiagozip/cap>
- Upstream docs: <https://trycap.dev>
- YunoHost package: <https://github.com/quartztester/cap_ynh>

## Debugging

- Logs: `journalctl -u cap -f`
- This package: `https://github.com/quartztester/cap_ynh`
