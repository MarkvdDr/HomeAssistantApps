# Prebuilt binaries

This directory contains the prebuilt binaries used by the normal `Dockerfile`,
so installing the add-on does not run a Go build on the Home Assistant host.

## Proton Mail Bridge binary (aarch64)

`aarch64/bridge` is the official Proton Mail Bridge CLI for Linux ARM64,
compiled from the upstream GPLv3 source at release tag `v3.27.1`. The normal
`Dockerfile` copies this file, so installing the add-on on a Raspberry Pi does
not run a Go build.

| File | Purpose |
| --- | --- |
| `aarch64/bridge` | 64-bit ARM (aarch64) Bridge 3.27.1 binary, mode `0755` |
| `aarch64/bridge.sha256.txt` | SHA-256 checksum of the binary |

Current checksum:

```text
3754845499fc034dd6f5f3bdb18b0127251ce62e1f1033cc21b7b6008f08706c
```

`amd64` does not use this folder; its Dockerfile downloads the official Proton
`.deb` release instead.

## Regenerate natively on aarch64

Use a Debian/Ubuntu aarch64 machine or container with build dependencies:

```bash
apt-get update
apt-get install -y --no-install-recommends \
  build-essential ca-certificates curl git pkg-config \
  libcbor-dev libfido2-dev libssl-dev libsecret-1-dev
```

Install the Go toolchain pinned by the upstream `go.mod` (1.26.7 for 3.27.1),
then build the release tag:

```bash
export PATH="/usr/local/go/bin:$PATH"
export GOTOOLCHAIN=local
export CGO_ENABLED=1
export GOFLAGS="-p=2"          # keep memory use reasonable on a Pi 4

git clone --depth 1 --branch v3.27.1 \
  https://github.com/ProtonMail/proton-bridge.git /src
cd /src
make build-nogui BRIDGE_APP_VERSION=3.27.1

install -m 0755 /src/bridge \
  /path/to/protonmail_bridge/prebuilt/aarch64/bridge
sha256sum /path/to/protonmail_bridge/prebuilt/aarch64/bridge \
  > /path/to/protonmail_bridge/prebuilt/aarch64/bridge.sha256.txt
```

## Regenerate with Dockerfile.source

`Dockerfile.source` is the slow build path and contains the same pinned version
and toolchain. Build only its `build` stage, then copy the binary out:

```bash
cd protonmail_bridge
docker buildx build --platform linux/arm64 \
  -f Dockerfile.source --target build -t proton-bridge-build .

docker create --name proton-bridge-build proton-bridge-build
docker cp proton-bridge-build:/bridge prebuilt/aarch64/bridge
docker rm proton-bridge-build

chmod 0755 prebuilt/aarch64/bridge
sha256sum prebuilt/aarch64/bridge > prebuilt/aarch64/bridge.sha256.txt
```

## Verify

```bash
prebuilt/aarch64/bridge --version
# Proton Mail Bridge 3.27.1

ldd prebuilt/aarch64/bridge
```

The runtime image installs the shared libraries the binary needs:
`libcbor0.10`, `libfido2-1`, `libglib2.0-0t64`, `libsecret-1-0` and
`libssl3t64`. If `ldd` reports a missing library, update the runtime package
list in the Dockerfile as well.

The binary must be committed with mode `0755`. A `.gitattributes` entry is not
needed; Git preserves the executable bit when the file is added normally.

## Hydroxide binaries (aarch64 and amd64)

`hydroxide/aarch64/hydroxide` and `hydroxide/amd64/hydroxide` are built from the
Hydroxide `v0.2.33` release and used only when `bridge_implementation` is set to
`hydroxide`.

| File | Purpose |
| --- | --- |
| `hydroxide/aarch64/hydroxide` | 64-bit ARM Hydroxide 0.2.33 binary, mode `0755` |
| `hydroxide/aarch64/hydroxide.sha256.txt` | SHA-256 checksum |
| `hydroxide/amd64/hydroxide` | 64-bit x86 Hydroxide 0.2.33 binary, mode `0755` |
| `hydroxide/amd64/hydroxide.sha256.txt` | SHA-256 checksum |

Current checksums:

```text
dc937ffd57e344eccbd922da0bfab2954f2d6c23dd524700499ab7bc7c1f562a  aarch64/hydroxide
763f133b9301b592806c4042c39483c6a42e48a4c7b46668c460bcc706b7a82f  amd64/hydroxide
```

### Regenerate

Install Go 1.26.11, then download and verify the pinned release archive:

```bash
curl -fL --retry 5 \
  -o /tmp/hydroxide-0.2.33.tar.gz \
  https://codeberg.org/emersion/hydroxide/releases/download/v0.2.33/hydroxide-0.2.33.tar.gz

echo "721e11afe574e2dad7f816ad0d49321f2e76bb8ed60e3f2355c894bc4e1fe20d  /tmp/hydroxide-0.2.33.tar.gz" \
  | sha256sum -c -

rm -rf /tmp/hydroxide-src
mkdir -p /tmp/hydroxide-src
tar -xzf /tmp/hydroxide-0.2.33.tar.gz -C /tmp/hydroxide-src --strip-components=1
```

Build both architectures from that source:

```bash
cd /tmp/hydroxide-src
export GOTOOLCHAIN=local
export CGO_ENABLED=0

GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "-s -w" \
  -o /path/to/protonmail_bridge/prebuilt/hydroxide/aarch64/hydroxide \
  ./cmd/hydroxide

GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "-s -w" \
  -o /path/to/protonmail_bridge/prebuilt/hydroxide/amd64/hydroxide \
  ./cmd/hydroxide
```

Set the executable bit and refresh the checksums:

```bash
cd /path/to/protonmail_bridge/prebuilt/hydroxide
chmod 0755 aarch64/hydroxide amd64/hydroxide
(cd aarch64 && sha256sum hydroxide > hydroxide.sha256.txt)
(cd amd64 && sha256sum hydroxide > hydroxide.sha256.txt)
```

### Verify

```bash
XDG_CONFIG_HOME=/tmp/hydroxide-check prebuilt/hydroxide/aarch64/hydroxide status
# No logged in user.

file prebuilt/hydroxide/aarch64/hydroxide prebuilt/hydroxide/amd64/hydroxide
```

The binaries are statically linked (`CGO_ENABLED=0`), so the runtime image needs
no extra Go or C libraries for them. It does install `openssl` to generate the
self-signed TLS certificate used by `hydroxide serve`.
