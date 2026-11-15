#!/usr/bin/env bash
# Entry point for the Proton Mail Bridge add-on.
set -euo pipefail

# Keep generated keyring and vault files private.
umask 077

export HOME=/data/home
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_RUNTIME_DIR=/run/proton-bridge

mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$HOME" "$XDG_RUNTIME_DIR"

echo "[init] Starting Proton Mail Bridge add-on"
echo "[init] Data directory: /data  (HOME=$HOME)"

# Select the bridge implementation before starting anything that only the
# official Bridge needs. A missing or invalid value safely means "official".
BRIDGE_IMPLEMENTATION="$(python3 -c 'import json; print(json.load(open("/data/options.json")).get("bridge_implementation", "official"))' 2>/dev/null || echo official)"
case "$BRIDGE_IMPLEMENTATION" in
    official|hydroxide) ;;
    *) BRIDGE_IMPLEMENTATION=official ;;
esac
export BRIDGE_IMPLEMENTATION
echo "[init] Bridge implementation: $BRIDGE_IMPLEMENTATION"

if [ "$BRIDGE_IMPLEMENTATION" = "official" ]; then
    # Bridge stores its vault key in the login keyring. The keyring password only
    # exists to unlock that keyring non-interactively at boot, so it is generated
    # once and kept next to the keyring in the persistent /data volume.
    if [ ! -s /data/.keyring_password ]; then
        python3 -c 'import secrets; print(secrets.token_urlsafe(32), end="")' > /data/.keyring_password
        chmod 600 /data/.keyring_password
        echo "[init] New keyring password generated in /data/.keyring_password"
    fi
    KEYRING_PASSWORD="$(cat /data/.keyring_password)"
    export KEYRING_PASSWORD

    # A private D-Bus session is required for gnome-keyring and for Bridge's
    # secret-service keychain helper. Start it here instead of wrapping the whole
    # entry point in dbus-run-session, so the Python process stays the container's
    # main process and receives SIGTERM directly for a clean shutdown.
    if DBUS_SESSION_BUS_ADDRESS="$(dbus-daemon --session --fork --print-address=1)"; then
        export DBUS_SESSION_BUS_ADDRESS
        echo "[init] Private D-Bus session started"
    else
        echo "[warn] Could not start a private D-Bus session; the keyring will be unavailable"
    fi
else
    echo "[init] Hydroxide mode: D-Bus and gnome-keyring are not needed"
fi

exec /app/start.sh
