# HomeAssistantApps

Apps and add-ons for Home Assistant.

## Projects

| Project | Type | Description |
| --- | --- | --- |
| [`protonmail_bridge/`](protonmail_bridge/) | Home Assistant add-on | Runs Proton Mail Bridge or the third-party Hydroxide bridge on Home Assistant OS and exposes IMAP/SMTP on ports `1143` and `1025`. |
| [`toonsim/`](toonsim/) | Home Assistant add-on | Runs ToonSim (a simulated Toon thermostat) with a browser touchscreen, Toon Mobile and firmware copied from a rooted Toon. |

## Proton Mail Bridge add-on

1. Open **Settings → Add-ons → Add-on store**.
2. Open the three-dot menu → **Repositories** and add
   `https://github.com/MarkvdDr/HomeAssistantApps`.
3. Install **Proton Mail Bridge**, start it and open **Proton Bridge** in the
   sidebar.

Full documentation: [`protonmail_bridge/README.md`](protonmail_bridge/README.md)
and [`protonmail_bridge/DOCS.md`](protonmail_bridge/DOCS.md).

## ToonSim add-on

1. Open **Settings → Apps → Install app → ⋮ → Repositories** and add
   `https://github.com/MarkvdDr/HomeAssistantApps`.
2. Wait until the **Build and publish ToonSim images** workflow has published
   the image to GitHub Container Registry.
3. Install **ToonSim** and set at least `toon_ip` and `toon_password`.

Full documentation: [`toonsim/README.md`](toonsim/README.md) and
[`toonsim/DOCS.md`](toonsim/DOCS.md).

## License

The add-on packaging is released under the MIT License; see
[`LICENSE`](LICENSE). The bundled Proton Mail Bridge is GPLv3 software by
Proton AG. See [`protonmail_bridge/NOTICE.md`](protonmail_bridge/NOTICE.md) for
the upstream source and license details.
