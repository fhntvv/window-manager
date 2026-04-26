import Testing
import CoreGraphics
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("CGEventTapAdapter – handleEvent")
struct CGEventTapHandleEventTests {

    private func makeKeyDownEvent(keyCode: UInt16 = 0x00, flags: CGEventFlags = []) throws -> CGEvent {
        let event = try #require(CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true))
        event.flags = flags
        return event
    }

    @Test func tapDisabledByTimeoutPassesEventThrough() throws {
        let adapter = CGEventTapAdapter()
        let event = try makeKeyDownEvent()

        let result = adapter.handleEvent(type: .tapDisabledByTimeout, event: event)

        #expect(result?.takeUnretainedValue() === event)
    }

    @Test func tapDisabledByUserInputPassesEventThrough() throws {
        let adapter = CGEventTapAdapter()
        let event = try makeKeyDownEvent()

        let result = adapter.handleEvent(type: .tapDisabledByUserInput, event: event)

        #expect(result?.takeUnretainedValue() === event)
    }

    @Test func keyDownWithoutControlOrCommandPassesThrough() throws {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return true
        }
        let event = try makeKeyDownEvent(flags: .maskShift)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result?.takeUnretainedValue() === event)
        #expect(!handlerCalled)
    }

    @Test func keyDownWithOnlyOptionPassesThrough() throws {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return true
        }
        let event = try makeKeyDownEvent(flags: .maskAlternate)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result?.takeUnretainedValue() === event)
        #expect(!handlerCalled)
    }

    @Test func keyDownWithControlCallsHandler() throws {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return false
        }
        let event = try makeKeyDownEvent(flags: .maskControl)

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(handlerCalled)
    }

    @Test func keyDownWithCommandCallsHandler() throws {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return false
        }
        let event = try makeKeyDownEvent(flags: .maskCommand)

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(handlerCalled)
    }

    @Test func handlerReceivesCorrectKeyCodeAndModifiers() throws {
        let adapter = CGEventTapAdapter()
        var receivedKeyCode: UInt16?
        var receivedModifiers: ModifierSet?
        adapter.handler = { keyCode, modifiers in
            receivedKeyCode = keyCode
            receivedModifiers = modifiers
            return false
        }
        let event = try makeKeyDownEvent(keyCode: 0x7B, flags: CGEventFlags([.maskControl, .maskAlternate]))

        _ = adapter.handleEvent(type: .keyDown, event: event)

        #expect(receivedKeyCode == 0x7B)
        #expect(receivedModifiers == [.control, .option])
    }

    @Test func handlerReturningTrueSwallowsEvent() throws {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in true }
        let event = try makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result == nil)
    }

    @Test func handlerReturningFalsePassesEventThrough() throws {
        let adapter = CGEventTapAdapter()
        adapter.handler = { _, _ in false }
        let event = try makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result?.takeUnretainedValue() === event)
    }

    @Test func keyDownWithNoHandlerPassesThrough() throws {
        let adapter = CGEventTapAdapter()
        let event = try makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .keyDown, event: event)

        #expect(result?.takeUnretainedValue() === event)
    }

    @Test func nonKeyDownEventPassesThrough() throws {
        let adapter = CGEventTapAdapter()
        var handlerCalled = false
        adapter.handler = { _, _ in
            handlerCalled = true
            return true
        }
        let event = try makeKeyDownEvent(flags: .maskControl)

        let result = adapter.handleEvent(type: .flagsChanged, event: event)

        #expect(result?.takeUnretainedValue() === event)
        #expect(!handlerCalled)
    }
}
