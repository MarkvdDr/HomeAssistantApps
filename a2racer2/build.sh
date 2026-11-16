#!/bin/sh
# Rebuild the WebAssembly bundle that the add-on ships in web/.
# The engine source, its patch and the toolchain live in engine/.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

exec "$HERE/engine/build-web.sh"
