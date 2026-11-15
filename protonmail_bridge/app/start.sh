#!/usr/bin/env bash
# Runs inside the container after run.sh has selected an implementation.
set -euo pipefail

if [ "${BRIDGE_IMPLEMENTATION:-official}" = "hydroxide" ]; then
    echo "[init] Hydroxide mode: skipping keyring unlock and socat forwarding"
    exec python3 /app/server.py
fi

# Unlock the login keyring before Bridge starts: the secret-service helper used
# by Bridge must be able to read the vault key without an interactive prompt.
if [ -n "${KEYRING_PASSWORD:-}" ]; then
    printf '%s' "$KEYRING_PASSWORD" \
        | gnome-keyring-daemon --unlock --daemonize --components=secrets >/dev/null 2>&1 || true
    echo "[init] gnome-keyring unlocked"
fi

# Give the secret service a moment to register on the session bus. Bridge falls
# back to insecure storage when no keyring is available, which would lose the
# vault key on the next restart.
SECRETS_READY=0
for _ in $(seq 1 20); do
    if dbus-send --session \
        --dest=org.freedesktop.DBus \
        --type=method_call \
        --print-reply \
        /org/freedesktop/DBus \
        org.freedesktop.DBus.NameHasOwner \
        string:org.freedesktop.secrets 2>/dev/null | grep -q 'boolean true'; then
        SECRETS_READY=1
        break
    fi
    sleep 0.25
done
if [ "$SECRETS_READY" = "1" ]; then
    echo "[init] secret service is ready"
else
    echo "[warn] secret service did not appear; Bridge may fall back to insecure storage"
fi

# Bridge only listens on 127.0.0.1. Forward the published IMAP/SMTP ports from
# the container address so other add-ons and LAN clients can reach it.
CONTAINER_IP="$(ip -4 route get 1.1.1.1 2>/dev/null \
    | awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}')"
if [ -z "$CONTAINER_IP" ]; then
    CONTAINER_IP="$(ip -4 -o addr show scope global 2>/dev/null \
        | awk '{print $4}' | cut -d/ -f1 | head -n1)"
fi

forward_port() {
    local port="$1"
    while :; do
        socat "TCP-LISTEN:${port},bind=${CONTAINER_IP},fork,reuseaddr" \
              "TCP:127.0.0.1:${port}" || true
        sleep 2
    done
}

if [ -n "$CONTAINER_IP" ]; then
    echo "[init] Forwarding IMAP/SMTP on ${CONTAINER_IP} (1143, 1025) to 127.0.0.1"
    forward_port 1143 &
    forward_port 1025 &
else
    echo "[warn] No container IPv4 address found; IMAP/SMTP forwarding is disabled"
fi

exec python3 /app/server.py
