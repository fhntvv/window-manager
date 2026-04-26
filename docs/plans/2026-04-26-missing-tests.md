# Missing Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three highest-value test gaps in the adapter layer — CGEventTapAdapter flag conversion, CGEventTapAdapter event routing, and TOMLConfigAdapter utility functions.

**Architecture:** Widen access levels on two private methods in CGEventTapAdapter so tests can call them directly with synthetic CGEvent objects (no accessibility required). TOMLConfigAdapter utilities are already public static — just need test cases.

**Tech Stack:** Swift Testing framework, CoreGraphics (CGEvent creation), @testable import

---

### Task 1: Widen CGEventTapAdapter access levels for testability

**Files:**
- Modify: `Sources/WindowManagerAdapters/CGEventTapAdapter.swift`

Three access-level changes — no logic changes.

- [x] **Step 1: Make `handler` property internal**

In `CGEventTapAdapter.swift`, change:

```swift
private var handler: ((_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)?
```

to:

```swift
var handler: ((_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)?
```

(Swift default access is `internal`, which `@testable import` exposes to tests.)

- [x] **Step 2: Make `handleEvent` internal**

Change:

```swift
fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
```

to:

```swift
func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
```

- [x] **Step 3: Make `convertFlags` internal**

Change:

```swift
private func convertFlags(_ flags: CGEventFlags) -> ModifierSet {
```

to:

```swift
func convertFlags(_ flags: CGEventFlags) -> ModifierSet {
```

- [x] **Step 4: Verify the project builds**

Run: `swift build 2>&1 | tail -5`
Expected: `Build complete!`

- [x] **Step 5: Commit**

```bash
git add Sources/WindowManagerAdapters/CGEventTapAdapter.swift
git commit -m "test: widen CGEventTapAdapter access levels for testability"
```

---

### Task 2: Test CGEventTapAdapter.convertFlags

**Files:**
- Create: `Tests/IntegrationTests/CGEventTapConvertFlagsTests.swift`

All tests are pure — no accessibility required.

- [x] **Step 1: Write the test file**

```swift
import Testing
import CoreGraphics
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("CGEventTapAdapter – convertFlags")
struct CGEventTapConvertFlagsTests {

    private let adapter = CGEventTapAdapter()

    @Test func controlFlagMapsToControl() {
        let result = adapter.convertFlags(CGEventFlags.maskControl)
        #expect(result.contains(.control))
        #expect(!result.contains(.option))
        #expect(!result.contains(.command))
        #expect(!result.contains(.shift))
    }

    @Test func optionFlagMapsToOption() {
        let result = adapter.convertFlags(CGEventFlags.maskAlternate)
        #expect(result.contains(.option))
        #expect(!result.contains(.control))
    }

    @Test func commandFlagMapsToCommand() {
        let result = adapter.convertFlags(CGEventFlags.maskCommand)
        #expect(result.contains(.command))
        #expect(!result.contains(.control))
    }

    @Test func shiftFlagMapsToShift() {
        let result = adapter.convertFlags(CGEventFlags.maskShift)
        #expect(result.contains(.shift))
        #expect(!result.contains(.control))
    }

    @Test func combinedControlOptionFlags() {
        let flags = CGEventFlags([.maskControl, .maskAlternate])
        let result = adapter.convertFlags(flags)
        #expect(result.contains(.control))
        #expect(result.contains(.option))
        #expect(!result.contains(.command))
        #expect(!result.contains(.shift))
    }

    @Test func allFourModifiers() {
        let flags = CGEventFlags([.maskControl, .maskAlternate, .maskCommand, .maskShift])
        let result = adapter.convertFlags(flags)
        #expect(result == [.control, .option, .command, .shift])
    }

    @Test func emptyFlagsReturnsEmptySet() {
        let result = adapter.convertFlags(CGEventFlags(rawValue: 0))
        #expect(result == ModifierSet())
    }

    @Test func irrelevantFlagsAreIgnored() {
        // alphaShift (caps lock) and numericPad should not produce any modifier
        let flags = CGEventFlags([.maskAlphaShift, .maskNumericPad])
        let result = adapter.convertFlags(flags)
        #expect(result == ModifierSet())
    }
}
```

- [x] **Step 2: Run tests to verify they pass**

Run: `swift test --filter CGEventTapConvertFlagsTests 2>&1 | tail -15`
Expected: 8 tests passed

- [x] **Step 3: Commit**

```bash
git add Tests/IntegrationTests/CGEventTapConvertFlagsTests.swift
git commit -m "test: add convertFlags tests for all modifier combinations"
```

---

### Task 3: Test CGEventTapAdapter.handleEvent routing

**Files:**
- Create: `Tests/IntegrationTests/CGEventTapHandleEventTests.swift`

These tests create synthetic `CGEvent` objects and call `handleEvent` directly — no event tap, no accessibility needed. `CGEvent(keyboardEventSource: nil, virtualKey:, keyDown:)` works without permissions.

- [ ] **Step 1: Write the test file**

```swift
import Testing
import CoreGraphics
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("CGEventTapAdapter – handleEvent")
struct CGEventTapHandleEventTests {

    private func makeKeyDownEvent(keyCode: UInt16 = 0x00, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        event.flags = flags
        return event
    }

    // MARK: – tap-disabled recovery

    @Test func tapDisabledByTimeoutPassesEventThrough() {
        let adapter = CGEventTapAdapter()
        let event = makeKeyDownEvent()

        let result = adapter.handleEvent(type: .tapDisabledByTimeout, event: event)

        #expect(result != nil) // event passed through, not swallowed
    }

    @Test func tapDisabledByUserInputPassesEventThrough() {
        let adapter = CGEventTapAdapter()
        let event = makeKeyDownEvent()

        let result = adapter.handleEvent(type: .tapDisabledByUserInput, event: event)

        #expect(result != nil)
    }

    // MARK: – early bail without control/command

    @Test func keyDownWithoutControlOrCommandPassesThrough() {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in true } // handler would match, but early bail skips it
        let event = makeKeyDownEvent(flags: .maskShift)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result != nil) // passed through — early bail
    }

    @Test func keyDownWithOnlyOptionPassesThrough() {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in true }
        let event = makeKeyDownEvent(flags: .maskAlternate)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result != nil)
    }

    // MARK: – handler dispatch

    @Test func keyDownWithControlCallsHandler() {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return false
        }
        let event = makeKeyDownEvent(flags: .maskControl)

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(handlerCalled)
    }

    @Test func keyDownWithCommandCallsHandler() {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return false
        }
        let event = makeKeyDownEvent(flags: .maskCommand)

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(handlerCalled)
    }

    @Test func handlerReceivesCorrectKeyCodeAndModifiers() {
        let adapter = CGEventTapAdapter()
        var receivedKeyCode: UInt16?
        var receivedModifiers: ModifierSet?
        adapter.handler = { keyCode, modifiers in
            receivedKeyCode = keyCode
            receivedModifiers = modifiers
            return false
        }
        let event = makeKeyDownEvent(keyCode: 0x7B, flags: CGEventFlags([.maskControl, .maskAlternate]))

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(receivedKeyCode == 0x7B)
        #expect(receivedModifiers == [.control, .option])
    }

    @Test func handlerReturningTrueSwallowsEvent() {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in true }
        let event = makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result == nil) // nil = event swallowed
    }

    @Test func handlerReturningFalsePassesEventThrough() {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in false }
        let event = makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result != nil) // event passed through
    }

    // MARK: – no handler set

    @Test func keyDownWithNoHandlerPassesThrough() {
        let adapter = CGEventTapAdapter()
        // handler is nil (no start() called)
        let event = makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result != nil)
    }

    // MARK: – non-keyDown event types

    @Test func nonKeyDownEventPassesThrough() {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in true }
        let event = makeKeyDownEvent(flags: .maskControl)

        // flagsChanged is not keyDown — should pass through even with handler
        let result = adapter.handleEvent(type: .flagsChanged, event: event)

        #expect(result != nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter CGEventTapHandleEventTests 2>&1 | tail -15`
Expected: 11 tests passed

- [ ] **Step 3: Commit**

```bash
git add Tests/IntegrationTests/CGEventTapHandleEventTests.swift
git commit -m "test: add handleEvent routing tests for event tap adapter"
```

---

### Task 4: Test TOMLConfigAdapter utility functions

**Files:**
- Create: `Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift`

`formatModifiers` and `keyName` are public static — no access level changes needed.

- [ ] **Step 1: Write the test file**

```swift
import Testing
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("TOMLConfigAdapter – utility functions")
struct TOMLConfigAdapterUtilTests {

    // MARK: – formatModifiers

    @Test func formatSingleControl() {
        let result = TOMLConfigAdapter.formatModifiers([.control])
        #expect(result == "ctrl")
    }

    @Test func formatSingleOption() {
        let result = TOMLConfigAdapter.formatModifiers([.option])
        #expect(result == "opt")
    }

    @Test func formatSingleCommand() {
        let result = TOMLConfigAdapter.formatModifiers([.command])
        #expect(result == "cmd")
    }

    @Test func formatSingleShift() {
        let result = TOMLConfigAdapter.formatModifiers([.shift])
        #expect(result == "shift")
    }

    @Test func formatControlOptionIsSorted() {
        let result = TOMLConfigAdapter.formatModifiers([.control, .option])
        #expect(result == "ctrl+opt")
    }

    @Test func formatAllModifiers() {
        let result = TOMLConfigAdapter.formatModifiers([.control, .option, .command, .shift])
        #expect(result == "ctrl+opt+cmd+shift")
    }

    @Test func formatEmptyModifiers() {
        let result = TOMLConfigAdapter.formatModifiers(ModifierSet())
        #expect(result == "")
    }

    // MARK: – keyName

    @Test func keyNameForLeftArrow() {
        let result = TOMLConfigAdapter.keyName(for: 0x7B)
        #expect(result == "left")
    }

    @Test func keyNameForReturnKey() {
        let result = TOMLConfigAdapter.keyName(for: 0x24)
        // reverseKeyCodeMap picks one name for duplicate keycodes (return/enter share 0x24)
        let valid = result == "return" || result == "enter"
        #expect(valid)
    }

    @Test func keyNameForUnknownKeycodeReturnsHex() {
        let result = TOMLConfigAdapter.keyName(for: 0xFF)
        #expect(result == "0xFF")
    }

    @Test func keyNameForLetterA() {
        let result = TOMLConfigAdapter.keyName(for: 0x00)
        #expect(result == "a")
    }
}
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `swift test --filter TOMLConfigAdapterUtilTests 2>&1 | tail -15`
Expected: 11 tests passed

- [ ] **Step 3: Commit**

```bash
git add Tests/IntegrationTests/TOMLConfigAdapterUtilTests.swift
git commit -m "test: add formatModifiers and keyName utility tests"
```

---

## Summary

| Task | Tests Added | What It Covers |
|------|------------|----------------|
| 1 | 0 (prep) | Access level changes for testability |
| 2 | 8 | All modifier flag → ModifierSet conversions |
| 3 | 11 | Event routing: tap-disabled recovery, early bail, handler dispatch, swallow vs pass-through |
| 4 | 11 | formatModifiers ordering/joining, keyName lookup + hex fallback |

**Total new tests: 30**
**Projected total: 102** (72 existing + 30 new)

### Not included (and why)

- **AppCompositionRoot** — hardcodes all dependencies, calls blocking `waitForAccessibility()`, starts `NSApplication.run()`. Testing would require DI refactoring that changes the architecture.
- **AXWindowAdapter.storeElement eviction** — all private, coupled to `AXUIElement`. 5 lines of code, not worth exposing internals.
- **Log.swift** — static logger declarations, nothing to test.
