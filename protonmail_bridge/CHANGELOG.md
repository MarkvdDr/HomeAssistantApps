# Changelog

## 1.2.2 - 2026-11-15

- Security: the Hydroxide sign-in no longer stores the Proton password or TOTP
  code in the browser's command history.
- The web panel shows a visible notice and an amber "Settings error" status when
  applying Bridge settings fails, instead of only a tooltip.
- Hydroxide restarts are no longer blocked after three consecutive server
  failures; the counter resets on add-on start, manual restart and a new login.
- Official mode restarts with exponential backoff (5, 10, 20, 40, then 60
  seconds) and resets after a run of at least 60 seconds.
- `Dockerfile.source` now ships `openssl` and the Hydroxide binary, so the
  source-built image also supports Hydroxide mode.
- The Docker build verifies the SHA-256 checksums of the prebuilt Bridge and
  Hydroxide binaries before installing them.
- The final Bridge output block is now flushed to the panel immediately.

## 1.2.1 - 2026-11-11

- Hydroxide now sends a real Proton web-client version
  (`web-mail@5.0.124.7`) instead of Hydroxide's default `Other` client string.
  Proton treats `Other` as a bot and forces a CAPTCHA that Hydroxide cannot pass,
  so this fixes the login loop. Override with the `HYDROXIDE_APP_VERSION`
  environment variable if Proton changes the value.
- Typing a bare Proton address in the web terminal now starts the Hydroxide
  login instead of being rejected as an unknown command.
- URLs in the web terminal (such as the CAPTCHA verification link) are now
  clickable.

## 1.2.0 - 2026-11-10

- Added the `bridge_implementation` option: choose `official` for Proton Mail
  Bridge (paid plan required) or `hydroxide` for the third-party Hydroxide
  bridge, which can be used with a free Proton account.
- Added Hydroxide `v0.2.33` prebuilt binaries for `aarch64` and `amd64`.
- Hydroxide mode has an ingress sign-in flow for the Proton password, TOTP and
  CAPTCHA, stores the generated Bridge password in `/data`, generates a
  self-signed TLS certificate and starts `hydroxide serve` automatically.
- Added Hydroxide commands `auth`, `status`, `password`, `restart` and
  `logout confirm`, plus mode-aware notices and mail client settings in the
  panel.
- Hydroxide uses implicit TLS (SSL) on ports `1143` and `1025`; official mode
  keeps its configurable STARTTLS/SSL behaviour and is still the default.
- Added Hydroxide documentation, MIT attribution and build instructions.

## 1.1.1 - 2026-11-10

- The web terminal now shows a notice that Proton Mail Bridge requires a paid
  Proton plan and cannot be used with a free Proton account.

## 1.1.0 - 2026-11-09

- Every runtime setting is now configurable from the add-on **Configuration**
  tab: log level, timezone, telemetry, alternative routing, All Mail
  visibility, Bridge self-updates, IMAP/SMTP security, IMAP/SMTP protocol
  logging and automatic restart.
- Settings are applied to Bridge automatically at add-on start; the web
  terminal is briefly read-only while they are applied.
- The ingress panel shows the configured IMAP/SMTP security instead of a fixed
  STARTTLS label.
- The `aarch64` Bridge 3.27.1 binary is now prebuilt and shipped in
  `prebuilt/aarch64/`, so installing the add-on on a Raspberry Pi no longer
  compiles Go. `Dockerfile.source` remains available to regenerate it.
- The old `/data/.autoupdate_disabled` marker is no longer used.

## 1.0.0 - 2026-11-09

- Initial release.
- Bundles Proton Mail Bridge 3.27.1.
- IMAP (1143) and SMTP (1025) with STARTTLS, forwarded from the container
  address to Bridge's localhost listeners.
- Ingress web terminal for `login`, `info`, `logout` and other Bridge CLI
  commands.
- Persistent vault and gnome-keyring login keyring in `/data`.
- Automatic Bridge restart, HTTP watchdog and cold backups.
- Bridge self-updates disabled on first start.
- Optional GitHub Actions workflow for prebuilt multi-arch images.
