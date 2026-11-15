# Proton Mail Bridge for Home Assistant OS

An unofficial Home Assistant add-on that runs either [Proton Mail Bridge](https://proton.me/mail/bridge)
or the third-party [Hydroxide](https://codeberg.org/emersion/hydroxide) bridge on
Home Assistant OS, exposing IMAP and SMTP servers for mail clients and Home
Assistant integrations.

> This project is not affiliated with Proton AG. Proton Mail Bridge itself is
> GPLv3 software; this repository only packages it for Home Assistant OS.
> Hydroxide is a separate MIT-licensed third-party project.

## Features

- Selectable bridge implementation in the add-on Configuration tab:
  - `official`: Proton Mail Bridge 3.27.1 (paid Proton plan required)
  - `hydroxide`: Hydroxide v0.2.33 (free Proton account possible, experimental)
- Official Bridge:
  - `amd64`: the official Proton `.deb` binary
  - `aarch64`: prebuilt from the upstream GPLv3 source at the same release
    tag and shipped in `protonmail_bridge/prebuilt/` (no Go build during
    add-on installation)
- Hydroxide: prebuilt for `aarch64` and `amd64`, with implicit TLS on ports
  `1143` and `1025`
- IMAP on port `1143` and SMTP on port `1025`, with STARTTLS or SSL in official
  mode and SSL in Hydroxide mode
- Every runtime setting in the add-on **Configuration** tab: implementation,
  log level, timezone, telemetry, alternative routing, All Mail visibility,
  Bridge self-updates, IMAP/SMTP security, protocol logging and automatic restart
- Ingress web terminal for `login`, `info`, `logout` and the other official
  Bridge commands, plus a Hydroxide sign-in flow with `auth`, `status`,
  `password` and `logout`
- Accounts, vault, keyring and Hydroxide credentials persist in the add-on's
  `/data` volume
- Automatic restart, HTTP watchdog and cold backups
- Bridge's own updater is disabled by default; updates are shipped through Home Assistant

## Requirements

- Home Assistant OS on `aarch64` or `amd64`
- For `official` mode: a **paid Proton Mail plan** (Mail Plus, Proton Unlimited,
  Proton Business, …). Proton Mail Bridge is not available on the free plan.
- For `hydroxide` mode: a Proton account, including a free one. Hydroxide is an
  unofficial third-party client; Proton may change or block its API, and use is
  at your own account risk.
- Free host ports `1143` and `1025`. You can change the host side later in the
  add-on's **Network** settings.

## Installation

### As a custom repository (recommended)

1. Make sure the repository is reachable on GitHub (this one, or your own fork).
2. In Home Assistant, open **Settings → Add-ons → Add-on store**.
3. Open the three-dot menu → **Repositories** and add:
   `https://github.com/MarkvdDr/HomeAssistantApps`
4. Install **Proton Mail Bridge**, start it, and open **Proton Bridge** in the
   sidebar.

### As a local add-on

Copy the `protonmail_bridge` folder to `/addons` (for example over Samba or SSH),
then reload the add-on store. Local add-ons are rebuilt by Home Assistant.

### Build time on a Raspberry Pi

The normal `Dockerfile` does not compile Go. On `amd64` it downloads and
unpacks the official Proton binary; on `aarch64` it copies the prebuilt Bridge
binary from `protonmail_bridge/prebuilt/aarch64/bridge`. The Hydroxide binaries
are also shipped prebuilt in `protonmail_bridge/prebuilt/hydroxide/`. A local
install therefore takes minutes rather than the 15–45 minutes of a source build.

`Dockerfile.source` is the slow source-build variant. It is only needed to
regenerate the prebuilt `aarch64` binary when the bundled Bridge version
changes; see `protonmail_bridge/prebuilt/README.md`.

If you do not want to build on the Pi at all, see
[Prebuilt images](#prebuilt-images-optional).

## First-time setup

Choose the implementation under **Settings → Add-ons → Proton Mail Bridge →
Configuration** and save. The add-on restarts.

### Official mode

1. Open the **Proton Bridge** panel.
2. Type `login` and press Enter.
3. Enter your full Proton address, your Proton password and your 2FA code.
   - If Bridge shows a human-verification URL, open it in a browser, complete
     the challenge, then press Enter in the terminal **with an empty input**.
   - TOTP authenticator codes work. Hardware security keys need USB access and
     are not supported by the default container.
4. After `Account … was added successfully`, run:

   ```text
   info
   ```

   or `info <account>` to show the IMAP/SMTP settings and the **Bridge
   password** for that account.

The Bridge password is different from your Proton account password. Use the
Bridge password in your mail client.

### Hydroxide mode

1. Set `bridge_implementation` to `hydroxide` and save. The add-on restarts.
2. Open the panel and enter your full Proton address under **Sign in**.
3. Enter your Proton password (or mailbox password, if your account uses two
   passwords) when prompted.
4. Enter your TOTP code if 2FA is enabled.
5. If Proton asks for human verification, open the shown URL in a browser,
   complete the challenge, then press Enter in the terminal **with an empty
   input**.
6. Wait for `Bridge password: …` and `Hydroxide server running`. The password is
   stored in `/data/hydroxide/bridge_password`; use the **bridge password**
   button to show it again later.

Hydroxide supports one Proton account per add-on and uses implicit TLS only.
Use **SSL**, not STARTTLS, in your mail client.

## Mail client settings

### Official mode

| Setting | Value |
| --- | --- |
| IMAP server | your Home Assistant host name or IP |
| IMAP port | `1143` |
| IMAP security | `STARTTLS` or `SSL`, from the add-on Configuration tab |
| SMTP server | your Home Assistant host name or IP |
| SMTP port | `1025` |
| SMTP security | `STARTTLS` or `SSL`, from the add-on Configuration tab |
| Username | your full Proton address |
| Password | the Bridge password from `info <account>` |

### Hydroxide mode

| Setting | Value |
| --- | --- |
| IMAP server | your Home Assistant host name or IP |
| IMAP port | `1143` |
| IMAP security | `SSL` (implicit TLS) |
| SMTP server | your Home Assistant host name or IP |
| SMTP port | `1025` |
| SMTP security | `SSL` (implicit TLS) |
| Username | your full Proton address |
| Password | the Bridge password shown after sign-in |

Both modes generate a self-signed certificate. Your mail client will ask you to
accept or trust it; that is expected. Do not expose ports `1143` or `1025`
directly to the internet.

Home Assistant's built-in SMTP notifier may reject the self-signed certificate.
Use a mail client that lets you trust the certificate, or add the Bridge CA to
the trust store of the client you use.

## Ports

| Container port | Default host port | Purpose |
| --- | --- | --- |
| `8099/tcp` | ingress only | web terminal and health check |
| `1143/tcp` | `1143` | IMAP (official: STARTTLS/SSL; Hydroxide: SSL) |
| `1025/tcp` | `1025` | SMTP (official: STARTTLS/SSL; Hydroxide: SSL) |

Other add-ons on the internal Docker network can reach the bridge at
`protonmail-bridge:1143` and `protonmail-bridge:1025`.

## Data and backups

Everything persistent lives in the add-on's `/data` volume:

- `/data/home` — official Bridge configuration, vault and logs
- `/data/.keyring_password` — generated keyring password for official mode
- `/data/home/.config/hydroxide/auth.json` — encrypted Hydroxide Proton login
- `/data/hydroxide/bridge_password` — Hydroxide Bridge password, mode `0600`
- `/data/hydroxide/tls.crt` and `/data/hydroxide/tls.key` — Hydroxide TLS pair

The add-on uses `backup: cold`, so Home Assistant stops it during a backup. A
restore brings back the vault, keyring and Hydroxide credentials together, so
accounts keep working without logging in again.

## Updating

- **Add-on updates:** increase `version` in `protonmail_bridge/config.yaml`,
  update `BRIDGE_VERSION` in the Dockerfile if needed, and publish the change.
  Home Assistant sees the new version and offers the update.
- **Bridge updates:** Bridge's self-updater is disabled by default. An update
  inside the container would be lost on the next restart (and Proton only
  publishes x86_64 builds), so updates belong in the add-on image. The
  `bridge_autoupdate` option can enable it, but that is not recommended.
- The add-on version is independent from the bundled bridge versions. The
  current bundled versions are Proton Mail Bridge `3.27.1` (official mode) and
  Hydroxide `0.2.33` (Hydroxide mode); see `CHANGELOG.md`,
  `BRIDGE_VERSION` and `prebuilt/README.md`.

## Prebuilt images (optional)

The included GitHub Actions workflow builds multi-arch images and publishes
them to GitHub Container Registry. This avoids any build on the Pi.

1. Push the repository to GitHub and open the **Actions** tab. The
   **Build Proton Mail Bridge add-on images** workflow runs on a
   `protonmail-bridge-v*` tag or manually.
2. Create and push a tag matching the add-on version, for example:

   ```bash
   git tag protonmail-bridge-v1.2.2
   git push origin protonmail-bridge-v1.2.2
   ```

3. Wait for the workflow to finish, then make the two packages
   (`ha-protonmail-bridge-aarch64` and `ha-protonmail-bridge-amd64`) public in
   the repository's **Packages** settings.
4. Uncomment the `image:` line in `protonmail_bridge/config.yaml`:

   ```yaml
   image: ghcr.io/markvddr/ha-protonmail-bridge-{arch}
   ```

5. Bump the add-on version, reload the store and update the add-on. Home
   Assistant now pulls the prebuilt image instead of compiling.

If the image cannot be pulled, comment the `image:` line again; Home Assistant
falls back to a local build.

## Troubleshooting

- **The panel shows `Bridge stopped` (official mode):** the process exited. Use
  **Restart**, then read the output in the terminal. The add-on log (`Settings →
  Add-ons → Proton Mail Bridge → Log`) shows the wrapper's own messages.
- **`secret service did not appear` in the log:** the keyring did not start.
  Restart the add-on. Without a keyring Bridge may store the vault key
  insecurely and ask you to log in again after a restart.
- **Official login fails:** check that your Proton plan includes Bridge, that
  IMAP/SMTP is enabled for the account, and that the 2FA code is current.
- **A free Proton account cannot log in to official mode:** that is Proton's
  restriction. Switch `bridge_implementation` to `hydroxide`, save, and sign in
  again in the panel.
- **Hydroxide shows `Not signed in`:** enter your Proton address under **Sign
  in**, or type `auth you@proton.me` in the terminal.
- **Hydroxide `Login did not complete`:** check the terminal output above. A
  wrong password, expired TOTP code or unfinished CAPTCHA all stop the login;
  run `auth <address>` again.
- **Hydroxide login was found but the bridge password is missing:** run `auth
  <address>` again. The login file cannot be decrypted without that password.
- **Hydroxide stopped repeatedly:** the Proton refresh token may have expired.
  Run `auth <address>` again, or `logout confirm` followed by a fresh sign-in.
- **Hydroxide mail client cannot connect:** use security `SSL` (implicit TLS),
  not STARTTLS, and accept the self-signed certificate.
- **The human-verification page is shown:** complete it in a browser, then
  press Enter in the terminal with an empty input.
- **Mail client cannot connect:** use the Home Assistant host, not
  `127.0.0.1`, and make sure host ports `1143`/`1025` are free. Check
  `Settings → Add-ons → Proton Mail Bridge → Network`.
- **Certificate warning:** expected; both modes use a self-signed certificate.
- **`info` shows `Address: 127.0.0.1`:** that is the official Bridge's internal
  bind address. In your mail client use the Home Assistant host name or IP
  instead.
- **Do not change the bridge's IMAP/SMTP ports in the CLI.** The add-on forwards
  or binds `1143` and `1025`; change the host-side mapping in the add-on's
  **Network** settings instead.

## Security

- The web terminal is served through Home Assistant ingress and is only
  available to administrators (`panel_admin: true`).
- IMAP/SMTP are published on the host. Keep them on your local network and do
  not forward them from your router.
- The Bridge password gives full IMAP/SMTP access to the account. Treat it like
  a password and do not paste it into untrusted clients.
- Hydroxide stores your Proton login encrypted with its Bridge password in
  `/data`, and stores that Bridge password in plain text with mode `0600` so the
  server can start unattended. Protect `/data` and any full add-on backup.
- Hydroxide talks to Proton's internal API rather than Proton's official Bridge
  API. Proton may restrict or block this, and use is at your own account risk.
- The add-on runs as root inside its own container, like most Home Assistant
  add-ons. It only mounts its private `/data` volume.

## Development

The add-on lives in `protonmail_bridge/`:

```text
protonmail_bridge/
├── app/
│   ├── index.html      # ingress terminal UI, mode-aware
│   ├── server.py       # HTTP server, PTY bridge, Hydroxide auth/serve
│   └── start.sh        # keyring/socat for official, web server for Hydroxide
├── config.yaml         # Home Assistant add-on manifest
├── Dockerfile          # fast build: Proton binaries + prebuilt Hydroxide
├── Dockerfile.source   # slow Proton source build, only for prebuilts
├── DOCS.md             # documentation shown in the add-on panel
├── icon.png
├── logo.png
├── prebuilt/           # prebuilt aarch64 Bridge binary and checksum
│   └── hydroxide/      # prebuilt Hydroxide binaries per architecture
├── run.sh              # container entry point, selects the implementation
└── translations/
```

The web server has no third-party Python dependencies. Validate the Python and
shell files with:

```bash
python3 -m py_compile protonmail_bridge/app/server.py
bash -n protonmail_bridge/run.sh
bash -n protonmail_bridge/app/start.sh
```

The normal Dockerfile does not download or build Go. The `aarch64` binary is
checked in at `protonmail_bridge/prebuilt/aarch64/bridge`, built from the
upstream `v3.27.1` tag with Go 1.26.7. Its SHA-256 checksum is stored next to
it. Use `Dockerfile.source` or the instructions in `prebuilt/README.md` to
regenerate it. A local Docker build is the only way to verify the complete
image; Home Assistant OS builds it for the host architecture.

## License

The add-on packaging, web terminal and documentation are released under the
MIT License (see `LICENSE`). Proton Mail Bridge is Copyright Proton AG and is
licensed under GPLv3; see `NOTICE.md` for details and upstream source links.
