# syntax=docker/dockerfile:1
#
# Proton Mail Bridge add-on image (fast build).
#
# aarch64: the Bridge binary is prebuilt and shipped in prebuilt/aarch64/bridge,
#          so installing the add-on on a Raspberry Pi does not compile Bridge
#          from source. Regenerate it with Dockerfile.source or the commands in
#          prebuilt/README.md when the bundled Bridge version changes.
# amd64:   the official Proton .deb release is downloaded and unpacked.
#
# Both architectures also ship a prebuilt Hydroxide binary in
# prebuilt/hydroxide/<arch>/hydroxide for the optional third-party mode.
#
FROM debian:trixie-slim AS build

ARG BRIDGE_VERSION=3.27.1
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

# Runtime libraries needed to execute `bridge --version` during the build and
# to make sure the prebuilt binary resolves all its shared libraries.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        dpkg \
        libcbor0.10 \
        libfido2-1 \
        libglib2.0-0t64 \
        libsecret-1-0 \
        libssl3t64 \
    && rm -rf /var/lib/apt/lists/*

COPY prebuilt/ /prebuilt/

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    if [ "$arch" = "amd64" ]; then \
        curl -fsSL --retry 5 --retry-delay 5 \
            -o /tmp/bridge.deb \
            "https://proton.me/download/bridge/protonmail-bridge_${BRIDGE_VERSION}-1_amd64.deb"; \
        dpkg-deb --fsys-tarfile /tmp/bridge.deb \
            | tar -xO ./usr/lib/protonmail/bridge/bridge > /bridge; \
        rm -f /tmp/bridge.deb; \
    elif [ "$arch" = "aarch64" ] || [ "$arch" = "arm64" ]; then \
        test -x /prebuilt/aarch64/bridge; \
        (cd / && sha256sum -c /prebuilt/aarch64/bridge.sha256.txt); \
        cp /prebuilt/aarch64/bridge /bridge; \
    else \
        echo "No prebuilt Proton Mail Bridge binary for architecture: ${arch}" >&2; \
        exit 1; \
    fi; \
    chmod 0755 /bridge; \
    /bridge --version

FROM debian:trixie-slim

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/data/home \
    XDG_CONFIG_HOME=/data/home/.config \
    XDG_DATA_HOME=/data/home/.local/share \
    XDG_CACHE_HOME=/data/home/.cache \
    XDG_RUNTIME_DIR=/run/proton-bridge \
    BRIDGE_BIN=/usr/lib/protonmail/bridge/bridge \
    PYTHONUNBUFFERED=1 \
    LANG=C.UTF-8

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        dbus \
        gnome-keyring \
        iproute2 \
        libcbor0.10 \
        libfido2-1 \
        libglib2.0-0t64 \
        libsecret-1-0 \
        libssl3t64 \
        openssl \
        python3 \
        socat \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /bridge /usr/lib/protonmail/bridge/bridge
RUN chmod 0755 /usr/lib/protonmail/bridge/bridge \
    && ln -sf /usr/lib/protonmail/bridge/bridge /usr/bin/proton-bridge

# Hydroxide is only used when bridge_implementation is set to hydroxide. The
# binaries are built from the pinned v0.2.33 release; see prebuilt/README.md.
COPY prebuilt/hydroxide/ /prebuilt/hydroxide/
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) hydroxide_arch=amd64 ;; \
        aarch64|arm64) hydroxide_arch=aarch64 ;; \
        *) echo "No prebuilt Hydroxide binary for architecture: ${arch}" >&2; exit 1 ;; \
    esac; \
    (cd "/prebuilt/hydroxide/${hydroxide_arch}" && sha256sum -c hydroxide.sha256.txt); \
    install -m 0755 "/prebuilt/hydroxide/${hydroxide_arch}/hydroxide" /usr/local/bin/hydroxide; \
    rm -rf /prebuilt/hydroxide; \
    XDG_CONFIG_HOME=/tmp/hydroxide-check /usr/local/bin/hydroxide status >/dev/null

COPY app/ /app/
COPY run.sh /run.sh
RUN chmod 0755 /run.sh /app/start.sh

EXPOSE 8099 1143 1025

CMD ["/run.sh"]
