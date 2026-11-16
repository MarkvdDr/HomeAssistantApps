#!/bin/sh
# Build the browser bundle of A2RacerIIRE, the engine behind this add-on.
#
# The engine source is not vendored: this fetches the pinned commit, applies
# engine/web.patch (the Emscripten platform layer) and writes the two files the
# add-on serves, web/a2racer2.js and web/a2racer2.wasm. The page and loader in
# web/ are hand-written and are left alone.
#
# Needs Emscripten (emcc) on PATH, or EMSDK pointing at an emsdk checkout.
# Build output: engine/build/A2RacerIIRE (git-ignored, src/ only).
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
WORK=${A2RACER2_BUILD_DIR:-"$HERE/build"}
SRC="$WORK/A2RacerIIRE"
REPO=https://github.com/jjmhalew/A2RacerIIRE.git
COMMIT=cbd3d78b11a70b901622fbd94d524a4829d7c062

EMCC=${EMCC:-emcc}
# emsdk_env.sh needs bash; add the same directories directly so this script
# also works when /bin/sh is dash.
if ! command -v "$EMCC" >/dev/null 2>&1 && [ -n "${EMSDK:-}" ]; then
    PATH="$EMSDK/upstream/emscripten:$EMSDK:$PATH"
    for node in "$EMSDK"/node/*/bin; do
        [ -d "$node" ] && PATH="$node:$PATH"
    done
    export PATH
fi
if ! command -v "$EMCC" >/dev/null 2>&1; then
    echo "emcc not found. Install Emscripten/emsdk and put emcc on PATH, or set EMSDK." >&2
    exit 1
fi

# A sparse, filtered checkout keeps this to a couple of MB; the upstream
# tools/ directory is over 100 MB and the build does not use it.
rm -rf "$SRC"
mkdir -p "$SRC"
git init -q "$SRC"
git -C "$SRC" remote add origin "$REPO"
git -C "$SRC" sparse-checkout init --cone
git -C "$SRC" sparse-checkout set src
git -C "$SRC" fetch -q --depth 1 --filter=blob:none origin "$COMMIT"
git -C "$SRC" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
git -C "$SRC" apply "$HERE/web.patch"

# The same source list as upstream's build.sh; the list is fixed with the
# commit above.
SOURCES="src/main.c src/plat_sdl.c src/pad.c src/touch.c src/gfx_gl.c src/res.c src/image.c src/ini.c \
src/audio.c src/smk.c src/film.c src/texture.c src/track.c src/datasetup.c src/exetab.c src/model.c \
src/objects.c src/race.c src/hud.c src/paths.c src/effects.c src/particles.c src/sfx.c src/rules.c \
src/font3d.c src/flag.c src/car_old.c src/wheels.c src/shadow.c src/lights.c src/fog.c src/ai.c \
src/collide.c src/menu.c src/menu_ui.c src/menu_screens.c src/game.c src/txcopy.c src/radar.c src/screen.c"

mkdir -p "$ROOT/web"
cd "$SRC"
# shellcheck disable=SC2086
"$EMCC" -std=gnu99 -O2 -ffp-contract=off -Isrc -D_FILE_OFFSET_BITS=64 \
    -sUSE_SDL=2 \
    -sMIN_WEBGL_VERSION=1 -sMAX_WEBGL_VERSION=1 \
    -sASYNCIFY \
    -sFORCE_FILESYSTEM=1 -lidbfs.js \
    -sALLOW_MEMORY_GROWTH=1 -sINITIAL_MEMORY=67108864 -sMAXIMUM_MEMORY=2147483648 \
    -sSTACK_SIZE=1048576 \
    -sINVOKE_RUN=0 -sEXIT_RUNTIME=1 \
    -sENVIRONMENT=web \
    -sEXPORTED_RUNTIME_METHODS=callMain,FS,IDBFS \
    -o "$ROOT/web/a2racer2.js" $SOURCES

echo "Wrote:"
ls -lh "$ROOT/web/a2racer2.js" "$ROOT/web/a2racer2.wasm"
