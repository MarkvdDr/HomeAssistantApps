# Third-party notices

## Proton Mail Bridge

This add-on packages [Proton Mail Bridge](https://proton.me/mail/bridge), which
is Copyright (c) Proton AG and licensed under the **GNU General Public License
version 3**.

- Upstream project: <https://github.com/ProtonMail/proton-bridge>
- Bundled release: `v3.27.1`
- Upstream source for that release:
  <https://github.com/ProtonMail/proton-bridge/tree/v3.27.1>
- License text: <https://github.com/ProtonMail/proton-bridge/blob/v3.27.1/LICENSE>

On `amd64` the image extracts the official binary from Proton's published
`protonmail-bridge_3.27.1-1_amd64.deb`. On `aarch64` the normal image uses the
prebuilt binary in `protonmail_bridge/prebuilt/aarch64/bridge`, which was
compiled from the same release tag from the upstream GPLv3 source.
`Dockerfile.source` contains the source-build recipe used to regenerate that
binary; no modifications are made to the Bridge source.

## Hydroxide

This add-on can optionally run [Hydroxide](https://codeberg.org/emersion/hydroxide),
a third-party, open-source ProtonMail CardDAV, IMAP and SMTP bridge.

- Upstream project: <https://codeberg.org/emersion/hydroxide>
- Bundled release: `v0.2.33` (2026-10-25)
- Release source archive:
  <https://codeberg.org/emersion/hydroxide/releases/download/v0.2.33/hydroxide-0.2.33.tar.gz>
- Source archive SHA-256:
  `721e11afe574e2dad7f816ad0d49321f2e76bb8ed60e3f2355c894bc4e1fe20d`
- License: MIT
- Bundled binaries were built from that release with Go 1.26.11 and
  `CGO_ENABLED=0`; no modifications are made to the Hydroxide source.
- Binary checksums:
  - `aarch64`: `dc937ffd57e344eccbd922da0bfab2954f2d6c23dd524700499ab7bc7c1f562a`
  - `amd64`: `763f133b9301b592806c4042c39483c6a42e48a4c7b46668c460bcc706b7a82f`

Hydroxide is not affiliated with Proton AG. It talks to Proton's internal API,
not the official Bridge API; Proton may change or block that API at any time.

```text
MIT License

Copyright (c) 2017 emersion

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Other components

The runtime image also contains Debian packages (Python, D-Bus, gnome-keyring,
socat, libfido2 and their dependencies) under their respective licenses. See
the Debian package metadata inside the image for details.
