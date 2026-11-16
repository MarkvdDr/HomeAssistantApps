# A2 Racer II Home Assistant add-on

Plays A2 Racer II in the browser through Home Assistant ingress. The engine is
[jjmhalew/A2RacerIIRE](https://github.com/jjmhalew/A2RacerIIRE), a
reimplementation in C, compiled to WebAssembly with Emscripten. It includes
the engine's own touch controls, which appear automatically on a touch device.

The add-on contains **no game data**. A2 Racer II is owned by Davilex; use your
own copy (Dutch version, v1.01).

## Install

1. In Home Assistant, open **Settings → Add-ons → Add-on store**.
2. Open the menu → **Repositories** and add
   `https://github.com/MarkvdDr/HomeAssistantApps`.
3. Install **A2 Racer II** and start it.
4. Put your own game files in `/share/A2racer2` (the folder name is
   case-sensitive). The add-on imports them automatically on the first start.
5. Open the add-on and press **Spelen**.

The complete `data` folder of the CD or installation is needed; the engine
checks at least `spel.dat`, `RCS.IMG`, `RCS.IND`, `etappe0.rmp` and
`Raser.ini`. A `data/` subfolder inside `/share/A2racer2` also works.

You can also choose a folder on the device with **Kies de gamemap…**. The
files and the saves are stored in the browser (IndexedDB); the add-on itself
keeps no game data.

## Build

The bundle in `web/` is committed, so the add-on image does not need
Emscripten. To rebuild it after changing the engine or `engine/web.patch`:

```sh
./build.sh
```

This fetches the pinned upstream commit, applies `engine/web.patch` and writes
`web/a2racer2.js` and `web/a2racer2.wasm`. Emscripten is only needed for this
build; see [`engine/README.md`](engine/README.md).

## Layout

| Path | Purpose |
|---|---|
| `config.yaml`, `Dockerfile` | Home Assistant add-on definition and image |
| `nginx.conf` | Static server on port 8099 and the `/game/` listing |
| `web/` | Page, loader and the prebuilt `a2racer2.js`/`.wasm` |
| `engine/` | Pinned upstream patch, GPLv3 licence and WASM build script |
| `build.sh` | Rebuilds the WASM bundle |
| `NOTICE` | Upstream, licence and attribution |

## Licence

The add-on packaging (nginx, Dockerfile, page and loader) is released under
the [BOLA License](LICENSE). The engine in `engine/` and the prebuilt
`web/a2racer2.js`/`web/a2racer2.wasm` are jjmhalew/A2RacerIIRE, licensed under
the GNU GPL v3 or later; see [`engine/LICENSE`](engine/LICENSE) and
[`NOTICE`](NOTICE). Neither licence covers the game. A2 Racer II, its data and
its box art belong to their rights holders.

Full Dutch documentation: [`DOCS.md`](DOCS.md).
