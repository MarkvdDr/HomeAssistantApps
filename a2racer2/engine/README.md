# The engine behind the add-on

The add-on runs [A2RacerIIRE](https://github.com/jjmhalew/A2RacerIIRE), a
reimplementation of A2 Racer II in C. It replaces the earlier berobloom port,
which is no longer part of this add-on (it remains in the git history). This
engine also builds for Android and the Nintendo Switch, and it has its own
touch controls.

The browser bundle in `../web/` is built from:

| Item | Value |
|---|---|
| Upstream | <https://github.com/jjmhalew/A2RacerIIRE> |
| Commit | `cbd3d78b11a70b901622fbd94d524a4829d7c062` |
| Local change | `web.patch` (only `src/plat_sdl.c`) |
| Compiler | Emscripten 6.0.13 |
| License | GNU GPL v3 or later; see `LICENSE` |

`web.patch` adds the browser platform layer: messages and questions are sent
to the page, the race starts with its touch controls on a touch-first device,
the frame swap yields to the browser at about 60 Hz, and the game uses `/data`
for the game files and `/user` for settings and saves (both mounted in
IndexedDB by the page). It does not change the game itself.

## Building

From the add-on directory:

```sh
./build.sh
```

or directly:

```sh
engine/build-web.sh
```

The script makes a sparse, filtered checkout of the pinned commit in
`engine/build/A2RacerIIRE` (only `src/`; the upstream `tools/` directory is
over 100 MB and is not needed), applies `web.patch`, and writes
`web/a2racer2.js` and `web/a2racer2.wasm`. `web/a2racer2.html` and
`web/loader.js` are not generated; they are maintained by hand.

You need Emscripten on `PATH`, or set `EMSDK` to an emsdk checkout. The add-on
image itself does not need the toolchain: it ships the prebuilt bundle.

## Updating the engine

1. Change `COMMIT` in `build-web.sh` to the new upstream commit.
2. Regenerate the patch against that commit. One way is to build a clean
   checkout, edit `src/plat_sdl.c` the same way, and run
   `git diff > engine/web.patch` from the checkout.
3. Build and test the page with your own A2 Racer II v1.01 data.
4. Commit the new `web.patch`, `web/a2racer2.js` and `web/a2racer2.wasm`
   together.

The upstream project's own README explains the desktop build and the game
data. No game data is included here.
