# Hint Overlay Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A dedicated hotkey (`ctrl+option+/`) toggles a floating panel listing all configured keybindings, so the user doesn't have to check config.toml.

**Architecture:** `showHints` is a new `WindowAction` case that flows through the existing hotkey pipeline. The composition root intercepts it and toggles an `NSPanel` overlay instead of calling `WindowOperationService`. The overlay reads `[HotkeyBinding]` on every toggle and formats using existing `TOMLConfigAdapter` utilities.

**Tech Stack:** Swift, AppKit (NSPanel, NSVisualEffectView, NSTextField)

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `Sources/WindowManagerDomain/Models/WindowAction.swift` | Add `showHints` case |
| Modify | `Sources/WindowManagerDomain/Services/TilingEngine.swift` | Handle `showHints` (compiler requirement) |
| Modify | `Sources/WindowManagerAdapters/TOMLConfigAdapter.swift` | Add `/` key code + `showHints` default binding |
| Create | `Sources/WindowManagerAdapters/HintOverlayPanel.swift` | NSPanel subclass showing binding list |
| Modify | `Sources/windowmanager/AppCompositionRoot.swift` | Wire overlay toggle on `.showHints` |
| Modify | `config.toml` | Add `showHints` binding entry |
| Modify | `Tests/DomainTests/HotkeyMatcherTests.swift` | Test matching `showHints` |
| Modify | `Tests/IntegrationTests/TOMLConfigAdapterTests.swift` | Update binding count 13 → 14 |
| Modify | `Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift` | Test `/` key name resolution |

---

### Task 1: Add `showHints` to `WindowAction` and handle in `TilingEngine`

**Files:**
- Modify: `Sources/WindowManagerDomain/Models/WindowAction.swift`
- Modify: `Sources/WindowManagerDomain/Services/TilingEngine.swift`
- Modify: `Tests/DomainTests/HotkeyMatcherTests.swift`

- [x] **Step 1: Write failing test — matcher matches showHints**

Add to `Tests/DomainTests/HotkeyMatcherTests.swift`:

```swift
@Test func showHintsActionMatches() {
    let bindings = [
        HotkeyBinding(modifiers: [.control, .option], keyCode: 0x2C, action: .showHints),
    ]
    let result = matcher.match(keyCode: 0x2C, modifiers: [.control, .option], bindings: bindings)
    #expect(result == .showHints)
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter HotkeyMatcherTests/showHintsActionMatches 2>&1`
Expected: Compilation error — `WindowAction` has no member `showHints`

- [x] **Step 3: Add `showHints` to `WindowAction`**

In `Sources/WindowManagerDomain/Models/WindowAction.swift`, add `showHints` after `prevDisplay`:

```swift
public enum WindowAction: String, CaseIterable, Equatable, Sendable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case maximize
    case fullscreen
    case center
    case nextDisplay
    case prevDisplay
    case showHints
}
```

- [x] **Step 4: Handle `showHints` in `TilingEngine`**

The switch in `TilingEngine.computeFrame` is exhaustive — the compiler requires handling the new case. `showHints` should never reach `computeFrame` (intercepted in composition root), but we must satisfy the compiler.

In `Sources/WindowManagerDomain/Services/TilingEngine.swift`, change:

```swift
        case .nextDisplay, .prevDisplay:
            return CGRect(origin: vf.origin, size: vf.size)
```

to:

```swift
        case .nextDisplay, .prevDisplay, .showHints:
            return CGRect(origin: vf.origin, size: vf.size)
```

- [x] **Step 5: Run tests to verify they pass**

Run: `swift test --filter HotkeyMatcherTests 2>&1`
Expected: All tests pass (including the new `showHintsActionMatches`)

- [x] **Step 6: Commit**

```bash
git add Sources/WindowManagerDomain/Models/WindowAction.swift \
       Sources/WindowManagerDomain/Services/TilingEngine.swift \
       Tests/DomainTests/HotkeyMatcherTests.swift
git commit -m "feat: add showHints to WindowAction enum"
```

---

### Task 2: Add `/` key code mapping and config binding

**Files:**
- Modify: `Sources/WindowManagerAdapters/TOMLConfigAdapter.swift`
- Modify: `config.toml`
- Modify: `Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift`
- Modify: `Tests/IntegrationTests/TOMLConfigAdapterTests.swift`

- [x] **Step 1: Write failing test — keyName for slash**

Add to `Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift`:

```swift
@Test func keyNameForSlash() {
    let result = TOMLConfigAdapter.keyName(for: 0x2C)
    #expect(result == "/")
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `swift test --filter TOMLConfigAdapterUtilTests/keyNameForSlash 2>&1`
Expected: FAIL — returns `"0x2C"` (hex fallback) instead of `"/"`

- [x] **Step 3: Add `/` to key code map**

In `Sources/WindowManagerAdapters/TOMLConfigAdapter.swift`, add to `canonicalKeyNames` array after the `(0x28, "k")` entry:

```swift
    (0x29, ";"), (0x2A, "\\"), (0x2B, ","), (0x2C, "/"),
```

Wait — we only need `/`. Add just:

```swift
    (0x2C, "/"),
```

after `(0x28, "k"),` in the canonicalKeyNames array. The exact location within the letter block:

```swift
    (0x26, "j"), (0x28, "k"), (0x2C, "/"), (0x2D, "n"), (0x2E, "m"),
```

Also add an alias in `keyNameAliases`:

```swift
    ("slash", "/"),
```

- [x] **Step 4: Run test to verify it passes**

Run: `swift test --filter TOMLConfigAdapterUtilTests/keyNameForSlash 2>&1`
Expected: PASS

- [x] **Step 5: Add `showHints` to default config and config.toml**

In `Sources/WindowManagerAdapters/TOMLConfigAdapter.swift`, in `makeDefaultConfig()`, add after the `prevDisplay` binding:

```swift
HotkeyBinding(modifiers: [.control, .option], keyCode: 0x2C, action: .showHints),
```

In `config.toml`, add at the end:

```toml
[[bindings]]
modifiers = "ctrl+option"
key = "/"
action = "showHints"
```

- [x] **Step 6: Update config test expectations**

In `Tests/IntegrationTests/TOMLConfigAdapterTests.swift`, update two binding count assertions from `13` to `14`:

In `loadValidConfig`:
```swift
#expect(config.bindings.count == 14)
```

In `missingFileReturnsDefaults`:
```swift
#expect(config.bindings.count == 14)
```

- [x] **Step 7: Run all config tests**

Run: `swift test --filter "TOMLConfigAdapter" 2>&1`
Expected: All pass

- [x] **Step 8: Commit**

```bash
git add Sources/WindowManagerAdapters/TOMLConfigAdapter.swift \
       config.toml \
       Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift \
       Tests/IntegrationTests/TOMLConfigAdapterTests.swift
git commit -m "feat: add slash key mapping and showHints default binding"
```

---

### Task 3: Create `HintOverlayPanel`

**Files:**
- Create: `Sources/WindowManagerAdapters/HintOverlayPanel.swift`

- [x] **Step 1: Create `HintOverlayPanel.swift`**

Create `Sources/WindowManagerAdapters/HintOverlayPanel.swift`:

```swift
import AppKit
import WindowManagerDomain

@MainActor
public final class HintOverlayPanel {
    private var panel: NSPanel?

    public init() {}

    public func toggle(bindings: [HotkeyBinding]) {
        if let existing = panel, existing.isVisible {
            existing.orderOut(nil)
            return
        }
        showPanel(bindings: bindings)
    }

    private func showPanel(bindings: [HotkeyBinding]) {
        let text = formatBindings(bindings)

        let textField = NSTextField(labelWithString: text)
        textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.textColor = .labelColor
        textField.alignment = .left
        textField.translatesAutoresizingMaskIntoConstraints = false

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12

        effect.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: effect.topAnchor, constant: 16),
            textField.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -16),
            textField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
        ])

        let contentSize = textField.intrinsicContentSize
        let panelWidth = contentSize.width + 40
        let panelHeight = contentSize.height + 32

        guard let screenFrame = NSScreen.main?.visibleFrame else { return }
        let panelX = screenFrame.midX - panelWidth / 2
        let panelY = screenFrame.midY - panelHeight / 2
        let panelRect = NSRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: panelRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.titleVisibility = .hidden
        p.titlebarAppearsTransparent = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = effect
        p.makeKeyAndOrderFront(nil)

        self.panel = p
    }

    private func formatBindings(_ bindings: [HotkeyBinding]) -> String {
        let lines = bindings
            .filter { $0.action != .showHints }
            .map { binding in
                let mods = TOMLConfigAdapter.formatModifiers(binding.modifiers)
                let key = TOMLConfigAdapter.keyName(for: binding.keyCode)
                let shortcut = "\(mods)+\(key)"
                return (shortcut, binding.action.rawValue)
            }

        let maxShortcutLen = lines.map(\.0.count).max() ?? 0

        return lines.map { shortcut, action in
            let padded = shortcut.padding(toLength: maxShortcutLen, withPad: " ", startingAt: 0)
            return "\(padded)    \(action)"
        }.joined(separator: "\n")
    }
}
```

Key decisions:
- `NSVisualEffectView` with `.hudWindow` material gives a native macOS frosted-glass look
- Filters out `showHints` itself from the list (no point showing the meta-binding)
- Column-aligned: shortcuts left-padded, actions right
- `.nonactivatingPanel` — doesn't steal focus from user's app
- `.floating` level — stays above normal windows
- Escape key dismisses automatically (NSPanel built-in behavior)
- Creates a fresh panel on each show (content always reflects current bindings)

- [x] **Step 2: Run full build to verify compilation**

Run: `swift build 2>&1`
Expected: Build succeeds

- [x] **Step 3: Commit**

```bash
git add Sources/WindowManagerAdapters/HintOverlayPanel.swift
git commit -m "feat: add HintOverlayPanel for keybinding cheat sheet"
```

---

### Task 4: Wire overlay toggle in `AppCompositionRoot`

**Files:**
- Modify: `Sources/windowmanager/AppCompositionRoot.swift`

- [x] **Step 1: Add `HintOverlayPanel` and wire `.showHints` in event tap handler**

In `Sources/windowmanager/AppCompositionRoot.swift`:

Add a new property:

```swift
private let hintOverlay: HintOverlayPanel
```

In `init()`, after `self.windowService = ...`:

```swift
self.hintOverlay = HintOverlayPanel()
```

In `run()`, replace the event tap handler block:

```swift
let bindings = config.bindings
let matcher = hotkeyMatcher
let service = windowService
let queue = operationQueue
let overlay = hintOverlay

let log = DebugLogger(subsystem: "com.windowmanager", category: "EventTap")
eventTap.start { keyCode, modifiers in
    guard let action = matcher.match(keyCode: keyCode, modifiers: modifiers, bindings: bindings) else {
        return false
    }
    log.info("Hotkey matched: \(action.rawValue)")
    guard action != .showHints else {
        DispatchQueue.main.async {
            overlay.toggle(bindings: bindings)
        }
        return true
    }
    queue.async {
        service.execute(action)
    }
    return true
}
```

- [x] **Step 2: Run full build**

Run: `swift build 2>&1`
Expected: Build succeeds

- [x] **Step 3: Run full test suite**

Run: `swift test 2>&1`
Expected: All tests pass

- [x] **Step 4: Commit**

```bash
git add Sources/windowmanager/AppCompositionRoot.swift
git commit -m "feat: wire hint overlay toggle in composition root"
```

---

### Task 5: Smoke test

- [x] **Step 1: Build and run**

```bash
swift build && .build/debug/windowmanager --debug
```

- [x] **Step 2: Verify**

1. Press `ctrl+option+/` — overlay should appear centered on screen with all bindings listed
2. Press `ctrl+option+/` again — overlay should dismiss
3. Press `Escape` — overlay should dismiss
4. Press `ctrl+option+/`, then `ctrl+option+left` — window should tile left, overlay stays visible
5. Verify overlay content matches your `config.toml` bindings
