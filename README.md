# HomeAssistantApps

Apps and add-ons for Home Assistant.

## Projects

| Project | Type | Description |
| --- | --- | --- |
| [`protonmail_bridge/`](protonmail_bridge/) | Home Assistant add-on | Runs Proton Mail Bridge or the third-party Hydroxide bridge on Home Assistant OS and exposes IMAP/SMTP on ports `1143` and `1025`. |
| [`toonsim/`](toonsim/) | Home Assistant add-on | Runs ToonSim (a simulated Toon thermostat) with a browser touchscreen, Toon Mobile and firmware copied from a rooted Toon. |
| [`a2racer2/`](a2racer2/) | Home Assistant add-on | Serves the jjmhalew/A2RacerIIRE browser port of A2 Racer II through Home Assistant ingress, with automatic touch controls; game data is imported from `/share/A2racer2`. |

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

## A2 Racer II add-on

1. Open **Settings → Add-ons → Add-on store**.
2. Open the three-dot menu → **Repositories** and add
   `https://github.com/MarkvdDr/HomeAssistantApps`.
3. Install **A2 Racer II** and start it.
4. Put your own game files in `/share/A2racer2` and open the add-on; the first
   start imports them into the browser. A2 Racer II itself is not included.

Full documentation: [`a2racer2/README.md`](a2racer2/README.md) and
[`a2racer2/DOCS.md`](a2racer2/DOCS.md).

## License

The add-on packaging is released under the MIT License; see
[`LICENSE`](LICENSE). The bundled Proton Mail Bridge is GPLv3 software by
Proton AG. See [`protonmail_bridge/NOTICE.md`](protonmail_bridge/NOTICE.md) for
the upstream source and license details. The A2 Racer II add-on packaging in
[`a2racer2/`](a2racer2/) is released under the BOLA License; see
[`a2racer2/LICENSE`](a2racer2/LICENSE). The bundled engine
(jjmhalew/A2RacerIIRE) is GPLv3 software; see
[`a2racer2/NOTICE`](a2racer2/NOTICE). A2 Racer II itself is not included.
