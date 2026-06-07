# Code signing

WindowManager signs every release build with a persistent self-signed certificate (CN `WindowManager Self-Signed`). The certificate is in `signing/signing.crt`; the private key is in `signing/signing.key` (and packaged for keychain import as `signing/signing.p12`).

## Why

macOS TCC (Accessibility, Input Monitoring, etc.) stores each permission grant alongside a *Designated Requirement* — a Code Signing predicate that the running binary must satisfy on every access check. When a binary is signed with a stable certificate, the requirement is pinned to that certificate's leaf hash, so the grant survives upgrades. When a binary is adhoc-signed (no certificate), TCC has to pin to the cdhash, which changes on every build — so the grant silently breaks on the next upgrade and the user has no idea why hotkeys stopped working.

Self-signing with one persistent certificate makes the grant survive every signed upgrade. The certificate is not Apple-issued (not a paid Developer ID), so macOS still treats the app as "from an unidentified developer" on first install, but TCC permission persistence is the only thing that matters here.

## First-time setup (local)

```sh
scripts/setup-signing.sh
```

Imports `signing/signing.p12` into the login keychain and verifies the identity is visible to `codesign`. Idempotent — safe to run again.

## Building locally

```sh
make install
```

Builds a signed bundle and installs to `/Applications/WindowManager.app`, replacing any existing install and restarting the app. Requires the signing identity from setup-signing above.

## Auto-start at login

`make install` launches the app once but does not register a login agent. To have WindowManager start automatically at login:

```sh
make autostart
```

Installs a LaunchAgent (`~/Library/LaunchAgents/com.windowmanager.plist`) pointing at the binary inside `/Applications/WindowManager.app`. Remove it with `make autostart-uninstall`.

## CI

The same `.p12` is base64-encoded into the `CODESIGN_P12` GitHub Actions secret with password `CODESIGN_P12_PASSWORD`. The release workflow (`.github/workflows/release.yml`) imports it into an ephemeral keychain for each release build, so CI artifacts carry the same leaf certificate as local installs — TCC sees them as the same identity.

## When the certificate is rotated

The current certificate is valid 2026 through 2036. When it's regenerated:

1. Replace the files in `signing/`.
2. Update the constant in `Sources/windowmanager/SigningExpectation.swift` to the new leaf SHA-1. Get it with:
   ```sh
   openssl x509 -in signing/signing.crt -outform der | shasum
   ```
3. Update the GitHub Actions secrets.
4. Tell users to remove and re-add WindowManager in System Settings → Privacy & Security → Accessibility once after upgrading, since the stored grant's code requirement no longer matches.
