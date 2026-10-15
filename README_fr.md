<h1>
  <img src="logos/cap.png" width="48" alt="cap captcha logo">
  cap pour YunoHost
</h1>

Captcha auto-hébergé respectueux de la vie privée : preuve de travail, sans
énigmes, sans pistage. Les visiteurs résolvent une petite preuve de travail
dans leur navigateur ; aucune donnée personnelle n'est collectée.

**Version livrée :** 3.1.13

## Caractéristiques

- Défis par preuve de travail (SHA-3), sans scripts tiers ni cookies
- Widget + API serveur pour vos propres sites (`/<siteKey>/challenge`,
  `/<siteKey>/redeem`, `/siteverify`)
- Tableau de bord d'administration des clés, protégé par le portail YunoHost
- Instance Redis privée (loopback uniquement)

## Intégration YunoHost

- L'interface d'administration (`/server/*`, `/auth/*`, `/public/*`) est
  protégée par le portail YunoHost (groupe `admins`). Les points de terminaison
  captcha restent publics pour les visiteurs anonymes.
- La clé d'administration est lisible après installation avec :
  `yunohost app setting cap admin_key`

## Liens

- Projet amont : <https://github.com/tiagozip/cap>
- Documentation amont : <https://trycap.dev>
- Paquet YunoHost : <https://github.com/quartztester/cap_ynh>

## Screenshots

![cap captcha — dashboard](./doc/screenshots/dashboard.png)

