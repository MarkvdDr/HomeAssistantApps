# Proton Mail Bridge

Runs a Proton mail bridge on Home Assistant OS and exposes IMAP/SMTP on ports
`1143` and `1025`. You can choose between Proton's official Bridge and the
third-party Hydroxide bridge.

## Configuration

All runtime settings are available under **Settings → Add-ons → Proton Mail
Bridge → Configuration**. The add-on restarts automatically after saving.

| Option | Default | Description |
| --- | --- | --- |
| `bridge_implementation` | `official` | `official` for Proton Mail Bridge, `hydroxide` for the third-party Hydroxide bridge. |
| `log_level` | `info` | Log level: `trace`, `debug`, `info`, `warn` or `error`. `trace` is mapped to `debug`. |
| `timezone` | `Europe/Amsterdam` | Time zone used by the bridge. |
| `telemetry_disabled` | `true` | Official only: disable Proton Bridge's anonymous usage diagnostics. |
| `proxy_allowed` | `false` | Official only: allow Proton's alternative routing. |
| `show_all_mail` | `true` | Official only: show the All Mail folder. |
| `bridge_autoupdate` | `false` | Official only: allow Bridge's built-in self-updater. |
| `imap_security` | `starttls` | Official only: `starttls` or `ssl` for IMAP. Hydroxide always uses SSL. |
| `smtp_security` | `starttls` | Official only: `starttls` or `ssl` for SMTP. Hydroxide always uses SSL. |
| `log_imap` | `off` | Official only: IMAP protocol logging. |
| `log_smtp` | `false` | Official only: SMTP protocol logging. |
| `auto_restart` | `true` | Restart the selected bridge automatically if its process exits. |

Protocol logging can contain decrypted mail data. Leave it off unless you are
troubleshooting.

The IMAP/SMTP **ports** are not options: change the host-side mapping under
**Settings → Add-ons → Proton Mail Bridge → Network**.

## Official mode

The default. Uses Proton Mail Bridge `3.27.1`, the official application.

### First start

1. Open the **Proton Bridge** panel in the sidebar.
2. Type `login` and press Enter.
3. Enter your full Proton address, password and 2FA code.
4. If a human-verification URL is shown, open it in a browser, complete the
   challenge and press Enter in the terminal with an empty input.
5. Run `info` or `info <account>` to show the Bridge password for your mail
   client.

### Mail client

| Setting | Value |
| --- | --- |
| IMAP | Home Assistant host, port `1143`, security from the Configuration tab |
| SMTP | Home Assistant host, port `1025`, security from the Configuration tab |
| Username | your full Proton address |
| Password | the Bridge password from `info <account>` |

Bridge uses a self-signed certificate; accept or trust it in your mail client.

## Hydroxide mode

The optional third-party mode. Hydroxide talks to Proton's API directly, so it
can be used with a **free Proton account**. It is not affiliated with Proton and
is marked experimental.

Hydroxide has no interactive shell. The add-on stores the generated Bridge
password so its server can start automatically after a restart.

### First start

1. Set `bridge_implementation` to `hydroxide` and save. The add-on restarts.
2. Open the panel and enter your full Proton address under **Sign in**.
3. Enter your Proton password (or mailbox password, if your account uses two
   passwords) when prompted.
4. If 2FA is enabled, enter the TOTP code.
5. If Proton asks for human verification, open the shown URL in a browser,
   complete the challenge, then press Enter in the terminal with an empty input.
6. Wait for `Bridge password: …` and `Hydroxide server running`. Use the
   **bridge password** button to show the password again later.

### Mail client

| Setting | Value |
| --- | --- |
| IMAP | Home Assistant host, port `1143`, security `SSL` (implicit TLS) |
| SMTP | Home Assistant host, port `1025`, security `SSL` (implicit TLS) |
| Username | your full Proton address |
| Password | the Bridge password shown after sign-in |

Hydroxide only supports implicit TLS, not STARTTLS. It uses a self-signed
certificate; accept or trust it in your mail client.

### Data and security

- The Proton login is encrypted in
  `/data/home/.config/hydroxide/auth.json`, using the Bridge password as its key.
- The Bridge password is stored in `/data/hydroxide/bridge_password` with mode
  `0600`. A full backup of the add-on therefore contains both files.
- The TLS certificate and key are stored in `/data/hydroxide/`.
- Switching between `official` and `hydroxide` does not delete either mode's
  data. `logout confirm` removes only the Hydroxide login and Bridge password.
- Use **Settings → Add-ons → Proton Mail Bridge → Configuration** to switch back
  to `official` at any time.

### Limitations

- Hydroxide supports **one Proton account per add-on** in this mode, because
  `serve` accepts a single Bridge password.
- Hydroxide's IMAP support is still work in progress. Basic IMAP and SMTP work,
  but not every folder operation or mail client is guaranteed.
- Only TOTP is supported for 2FA. Hardware security keys (FIDO2) are not.
- A refresh-token expiry can require signing in again, especially with 2FA.
- Proton may change or block its API at any time. Using Hydroxide is at your own
  account risk; Proton's terms may restrict unofficial clients.
- Hydroxide is not affiliated with Proton AG.

## Notes

- Official mode requires a paid Proton Mail plan. Proton does not offer
  IMAP/SMTP on the free plan, so a free Proton account cannot log in to the
  official Bridge.
- Accounts and the official Bridge vault persist in `/data`.
- On `aarch64` the official Bridge binary is shipped prebuilt, so installing the
  add-on does not compile Go on the Raspberry Pi.
- Hydroxide `v0.2.33` is shipped prebuilt for `aarch64` and `amd64`; see
  `NOTICE.md` and `prebuilt/README.md`.

See the repository README for full documentation, prebuilt images and
troubleshooting.
