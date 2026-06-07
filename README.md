# WindowManager

A lightweight, keyboard-driven window manager for macOS. It snaps the focused window to halves, quarters, fullscreen, or across displays using global hotkeys. It runs as a background menu-less agent (no Dock icon) and is configured with a simple TOML file.

## Requirements

- macOS 13 (Ventura) or later
- Apple Silicon or Intel Mac

## Install

### Homebrew (recommended)

```sh
brew install --cask fhntvv/apps/windowmanager
```

This installs `WindowManager.app` into `/Applications` and launches it.

WindowManager is signed with a self-managed certificate rather than an Apple-issued Developer ID, so macOS still considers it an app "from an unidentified developer". The cask clears the quarantine flag for you. If you ever install the DMG manually instead of through Homebrew, right-click the app and choose **Open** the first time to get past Gatekeeper.

### Grant Accessibility permission

WindowManager moves and resizes windows through the macOS Accessibility API, so it needs Accessibility access before any hotkey will work:

1. On first launch, a system prompt appears. Click **Open System Settings** (or open **System Settings → Privacy & Security → Accessibility** yourself).
2. Turn on the switch next to **WindowManager**.

Hotkeys begin working within a couple of seconds — no restart is required. Because the app is signed with a stable certificate, this grant persists across future upgrades; you only need to do it once.

If you upgrade from a much older, unsigned build and hotkeys stop working, the stored permission may be pinned to the old binary. Remove WindowManager from the Accessibility list with the **−** button, then re-add and re-enable it.

## Default hotkeys

All default bindings use **Control + Option** together with another key:

| Keys | Action |
| --- | --- |
| Control + Option + ← / → | Left / right half |
| Control + Option + ↑ / ↓ | Top / bottom half |
| Control + Option + U / I | Top-left / top-right quarter |
| Control + Option + J / K | Bottom-left / bottom-right quarter |
| Control + Option + Return | Maximize |
| Control + Option + F | Fullscreen |
| Control + Option + C | Center |
| Control + Option + Command + ← / → | Move to previous / next display |
| Control + Option + / | Show the hotkey overlay |

## Configuration

Bindings and layout settings live in `~/.config/windowmanager/config.toml`. Edit that file to change keys or actions, then restart WindowManager to apply the changes.

## Start at login

Add **WindowManager.app** under **System Settings → General → Login Items**.

If you installed from source, you can instead register a managed launch agent that also restarts the app if it ever exits:

```sh
make autostart            # install and start the login agent
make autostart-uninstall  # remove it
```

## Build from source

For development, or to install a locally built and signed copy:

```sh
git clone https://github.com/fhntvv/window-manager.git
cd window-manager
make setup-signing   # imports the signing identity into your keychain (requires signing materials from the maintainer)
make install         # builds, signs, installs to /Applications, and launches the app
```

Then grant Accessibility as described above. See [`signing/README.md`](signing/README.md) for details on the code-signing setup and why it exists.

## Uninstall

Homebrew install:

```sh
brew uninstall --cask windowmanager
```

Source install:

```sh
make autostart-uninstall          # if you registered the login agent
rm -rf /Applications/WindowManager.app
```

In both cases, also remove WindowManager from **System Settings → Privacy & Security → Accessibility**.
