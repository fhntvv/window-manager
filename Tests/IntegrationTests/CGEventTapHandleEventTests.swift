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
