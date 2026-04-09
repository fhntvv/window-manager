# Window Manager Daemon — Hexagonal Architecture Design

Build a minimal macOS window manager daemon (macOS 13-15) that tiles windows via global hotkeys. Swift + TOML + CGEventTap + AXUIElement. Hexagonal architecture with compiler-enforced module boundaries for testability — domain logic (tiling math, hotkey matching, operation orchestration) must be fully unit-testable without Accessibility permissions or real displays.

## Design Decisions

- **Multi-module SPM over single target:** 3 SPM targets enforce hex boundaries at compile time. `WindowManagerDomain` cannot import AppKit — if it tries, the build fails. This is the testability payoff: `DomainTests` imports only the domain module and runs anywhere.
- **AX coordinates as canonical system:** All domain models use top-left origin (CGEventTap/AXUIElement coordinate system). The `NSScreenAdapter` handles the NSScreen bottom-left → AX top-left conversion. Domain code never touches NSScreen coordinates.
- **Modifier string parsing in adapter, not domain:** `"ctrl+option+left"` → `ModifierSet` + keyCode conversion is config-format-specific. Lives in `TOMLConfigAdapter`. Domain works with typed `HotkeyBinding` structs.
- **FrameRenderer for visual test debugging:** ASCII renderer in the domain layer takes screen configs + window rects → produces diagrams. Tests print before/after layouts to catch coordinate bugs visually.
- **LSUIElement, not LSBackgroundOnly:** macOS 15 Sequoia silently breaks event taps for `LSBackgroundOnly` apps. `LSUIElement = true` retains window-server access without Dock icon.
- **Triple-write for cross-display moves:** macOS clamps window size to current screen before honoring position change. Pattern: shrink → move → resize. Matches Rectangle's approach.

## Architecture

```
┌─────────────────────────────┐
│    windowmanager (exe)      │  main.swift, AppCompositionRoot
│    imports: Domain,         │  Wires adapters → ports → services
│    Adapters                 │
└──────────────┬──────────────┘
               │
       ┌───────┴───────┐
       │               │
┌──────┴──────┐  ┌─────┴───────┐
│  Adapters   │  │   Domain    │
│  (AppKit,   │  │  (pure      │
│   AX, CG)  │  │   Swift)    │
│  imports:   │  │  NO AppKit  │
│  Domain     │  │  NO CG/AX  │
└─────────────┘  └─────────────┘

Test targets:
  DomainTests      → imports Domain only (no permissions)
  IntegrationTests → imports Adapters (needs Accessibility)
```

### Domain layer

**Models** (`Sources/WindowManagerDomain/Models/`):

- `WindowRef` — opaque handle (int id). Domain doesn't know it's an AXUIElement.
- `WindowInfo` — position (CGPoint, AX coords), size, screenID, isFullscreen
- `ScreenInfo` — id, frame, visibleFrame (both AX coords), isPrimary
- `WindowAction` — enum: leftHalf, rightHalf, topHalf, bottomHalf, topLeft, topRight, bottomLeft, bottomRight, maximize, center, nextDisplay, prevDisplay
- `HotkeyBinding` — ModifierSet (OptionSet) + keyCode + action
- `Config` — bindings list + GeneralConfig (padding, animation)
- `ModifierSet` — OptionSet with control, option, command, shift

**Ports** (`Sources/WindowManagerDomain/Ports/`):

```swift
protocol WindowAccessPort {
    func getFocusedWindow() -> WindowInfo?
    func setWindowFrame(_ window: WindowRef, position: CGPoint, size: CGSize) -> Bool
    func getWindowInfo(_ window: WindowRef) -> WindowInfo?
}

protocol ScreenInfoPort {
    func allScreens() -> [ScreenInfo]
    func screenContaining(point: CGPoint) -> ScreenInfo?
    func primaryScreenHeight() -> CGFloat
}

protocol ConfigPort {
    func loadConfig() throws -> Config
}

protocol EventTapPort {
    func start(handler: @escaping (_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)
    func stop()
    func ensureEnabled()
}
```

**Services** (`Sources/WindowManagerDomain/Services/`):

- `TilingEngine` — pure struct. `computeFrame(action:screen:currentWindow:) -> CGRect`. No side effects, no port dependencies. Handles padding math.
- `HotkeyMatcher` — pure struct. `match(keyCode:modifiers:) -> WindowAction?`. Linear scan over bindings.
- `WindowOperationService` — orchestrator class. Injected with `WindowAccessPort`, `ScreenInfoPort`, `TilingEngine`. `execute(_ action:)` gets focused window, finds screen, computes frame, writes frame. Handles nextDisplay/prevDisplay triple-write.
- `FrameRenderer` — pure struct. `render(screens:windows:scale:) -> String`. ASCII art renderer for test debugging.

### Adapter layer

**Adapters** (`Sources/WindowManagerAdapters/`):

- `AXWindowAdapter: WindowAccessPort` — AXUIElement calls. getFocusedWindow via system-wide element → focused app → focused window. setWindowFrame writes kAXPositionAttribute + kAXSizeAttribute. Retry logic (3x, 50ms) for Electron apps.
- `NSScreenAdapter: ScreenInfoPort` — NSScreen.screens → ScreenInfo with coordinate conversion (`axY = primaryHeight - nsY - height`). Caches screens, invalidates on didChangeScreenParametersNotification.
- `CGEventTapAdapter: EventTapPort` — CGEvent.tapCreate, CFRunLoopSource. Converts CGEventFlags → ModifierSet. Returns nil to swallow matched events. ensureEnabled re-enables auto-disabled taps.
- `TOMLConfigAdapter: ConfigPort` — reads ~/.config/windowmanager/config.toml. Parses modifier strings, maps key names to virtual keycodes. Falls back to defaults.

### Composition root

`AppCompositionRoot` in the executable target. Checks Accessibility permission (polls until granted), loads config, creates adapters, wires to services, starts event tap, runs health-check timer (5s), enters NSApplication run loop with `.accessory` activation policy.

## TilingEngine frame calculations

All operations take `screen.visibleFrame` (AX coords) and optional padding `p`:

| Action | x | y | width | height |
|--------|---|---|-------|--------|
| leftHalf | vf.x + p | vf.y + p | vf.w/2 - 1.5p | vf.h - 2p |
| rightHalf | vf.midX + 0.5p | vf.y + p | vf.w/2 - 1.5p | vf.h - 2p |
| topHalf | vf.x + p | vf.y + p | vf.w - 2p | vf.h/2 - 1.5p |
| bottomHalf | vf.x + p | vf.midY + 0.5p | vf.w - 2p | vf.h/2 - 1.5p |
| topLeft | vf.x + p | vf.y + p | vf.w/2 - 1.5p | vf.h/2 - 1.5p |
| topRight | vf.midX + 0.5p | vf.y + p | vf.w/2 - 1.5p | vf.h/2 - 1.5p |
| bottomLeft | vf.x + p | vf.midY + 0.5p | vf.w/2 - 1.5p | vf.h/2 - 1.5p |
| bottomRight | vf.midX + 0.5p | vf.midY + 0.5p | vf.w/2 - 1.5p | vf.h/2 - 1.5p |
| maximize | vf.x + p | vf.y + p | vf.w - 2p | vf.h - 2p |
| center | vf.midX - w/2 | vf.midY - h/2 | (preserve) | (preserve) |

nextDisplay/prevDisplay handled by WindowOperationService — finds next screen, executes triple-write.

## Testing strategy

### Domain tests (DomainTests target, no permissions)

**TilingEngineTests** — pure math, no fakes needed:
- All 12 actions on a 1920x1080 screen with padding=0
- Padding > 0: verify all edges shrink correctly
- Menu bar offset: visibleFrame.y=25, verify tiling respects it
- Secondary display offset: screen at x=1920, verify origin shifts
- Center: preserves window size, centers in visibleFrame

**HotkeyMatcherTests** — pure lookup:
- Exact match returns correct action
- Missing modifier → nil
- Superset modifiers → nil
- Unknown keycode → nil
- Empty bindings → always nil

**WindowOperationServiceTests** — orchestration via fakes:
- `FakeWindowAccess` records setFrameCalls, returns preset focusedWindow
- `FakeScreenInfo` returns configurable screen list
- leftHalf: verify single setWindowFrame call with correct width
- No focused window: no setWindowFrame calls
- Fullscreen window: skipped
- nextDisplay: verify 3 setWindowFrame calls (triple-write), final position on screen2
- prevDisplay: wraps from screen1 to last screen

**ConfigTests** — model creation:
- Config with bindings and general settings
- Default GeneralConfig values
- ModifierSet contains/doesn't-contain checks

**FrameRendererTests** — visual debugging:
- Render leftHalf before/after → diagram contains both labels
- Render dual display with window migration → both screens visible
- Render all four quarters → all labels present

### Integration tests (IntegrationTests target, needs Accessibility)

All guarded by `try XCTSkipUnless(AXIsProcessTrusted())`.

- **NSScreenAdapterTests** — allScreens non-empty, primary isPrimary, visibleFrame within frame
- **AXWindowAdapterTests** — getFocusedWindow returns valid dimensions (if window focused)
- **CGEventTapAdapterTests** — tap creation succeeds, start/stop don't crash
- **TOMLConfigAdapterTests** — load valid config, missing file throws

## File map

| File | Responsibility |
|------|---------------|
| `Package.swift` | 3 targets (Domain lib, Adapters lib, exe) + 2 test targets. Single dep: TOMLDecoder |
| `Sources/WindowManagerDomain/Models/WindowRef.swift` | Opaque window handle |
| `Sources/WindowManagerDomain/Models/WindowInfo.swift` | Window position/size/screen/fullscreen |
| `Sources/WindowManagerDomain/Models/ScreenInfo.swift` | Screen geometry in AX coords |
| `Sources/WindowManagerDomain/Models/WindowAction.swift` | Enum of all tiling operations |
| `Sources/WindowManagerDomain/Models/HotkeyBinding.swift` | ModifierSet + keyCode + action |
| `Sources/WindowManagerDomain/Models/Config.swift` | Config + GeneralConfig structs |
| `Sources/WindowManagerDomain/Ports/WindowAccessPort.swift` | Protocol for window read/write |
| `Sources/WindowManagerDomain/Ports/ScreenInfoPort.swift` | Protocol for screen geometry |
| `Sources/WindowManagerDomain/Ports/ConfigPort.swift` | Protocol for config loading |
| `Sources/WindowManagerDomain/Ports/EventTapPort.swift` | Protocol for hotkey input |
| `Sources/WindowManagerDomain/Services/TilingEngine.swift` | Pure tiling math |
| `Sources/WindowManagerDomain/Services/HotkeyMatcher.swift` | Hotkey → action lookup |
| `Sources/WindowManagerDomain/Services/WindowOperationService.swift` | Orchestrator |
| `Sources/WindowManagerDomain/Services/FrameRenderer.swift` | ASCII diagram renderer |
| `Sources/WindowManagerAdapters/AXWindowAdapter.swift` | AXUIElement window manipulation |
| `Sources/WindowManagerAdapters/NSScreenAdapter.swift` | NSScreen → ScreenInfo + coord conversion |
| `Sources/WindowManagerAdapters/CGEventTapAdapter.swift` | CGEventTap hotkey input |
| `Sources/WindowManagerAdapters/TOMLConfigAdapter.swift` | TOML parsing + key mapping |
| `Sources/windowmanager/main.swift` | Entry point |
| `Sources/windowmanager/AppCompositionRoot.swift` | Dependency wiring |
| `Tests/DomainTests/TilingEngineTests.swift` | Tiling math tests |
| `Tests/DomainTests/HotkeyMatcherTests.swift` | Hotkey matching tests |
| `Tests/DomainTests/WindowOperationServiceTests.swift` | Orchestration tests with fakes |
| `Tests/DomainTests/ConfigTests.swift` | Config model tests |
| `Tests/DomainTests/FrameRendererTests.swift` | Visual debugger tests |
| `Tests/DomainTests/Fakes/FakeWindowAccess.swift` | WindowAccessPort test double |
| `Tests/DomainTests/Fakes/FakeScreenInfo.swift` | ScreenInfoPort test double |
| `Tests/IntegrationTests/Helpers/AccessibilitySkip.swift` | XCTSkipUnless helper |
| `Tests/IntegrationTests/AXWindowAdapterTests.swift` | Real AX API tests |
| `Tests/IntegrationTests/NSScreenAdapterTests.swift` | Real NSScreen tests |
| `Tests/IntegrationTests/CGEventTapAdapterTests.swift` | Real event tap tests |
| `Tests/IntegrationTests/TOMLConfigAdapterTests.swift` | Real TOML parsing tests |
| `Resources/Info.plist` | LSUIElement=true, Accessibility usage description |
| `Resources/Entitlements.plist` | Empty (no sandbox, no HR exceptions) |
| `config.toml` | Default hotkey config |
| `com.windowmanager.plist` | LaunchAgent for auto-start |

## Known gotchas

1. **CGEventTap auto-disable** — macOS kills taps whose callbacks exceed ~500ms. Health-check timer re-enables via `CGEvent.tapEnable`. Keep callback fast.
2. **Coordinate conversion** — NSScreen is bottom-left origin, AX is top-left. Formula: `axY = primaryHeight - nsY - height`. All conversion in NSScreenAdapter.
3. **Triple-write for cross-display** — shrink → move → resize. macOS clamps window size to current screen before honoring position change.
4. **LSUIElement not LSBackgroundOnly** — Sequoia breaks event taps for background-only apps.
5. **Re-signing invalidates TCC** — each re-sign requires re-granting Accessibility. Use stable ad-hoc signature during dev.
6. **Electron app retry** — AX operations on VS Code, Slack need 3 retries with 50ms delays.
7. **Fullscreen check** — always check isFullscreen before operations. AX calls silently fail on fullscreen windows.
8. **Minimum window sizes** — some apps clamp size. Read back after setting, adjust position if actual != requested.
