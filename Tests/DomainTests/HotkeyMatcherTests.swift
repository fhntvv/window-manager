import Testing
@testable import WindowManagerDomain

@Suite("HotkeyMatcher")
struct HotkeyMatcherTests {

    let matcher = HotkeyMatcher()

    let bindings: [HotkeyBinding] = [
        HotkeyBinding(modifiers: [.control, .option], keyCode: 123, action: .leftHalf),
        HotkeyBinding(modifiers: [.control, .option], keyCode: 124, action: .rightHalf),
        HotkeyBinding(modifiers: [.control, .option], keyCode: 126, action: .topHalf),
        HotkeyBinding(modifiers: [.control, .option], keyCode: 125, action: .bottomHalf),
        HotkeyBinding(modifiers: [.control, .option], keyCode: 36, action: .maximize),
    ]

    @Test func exactMatchReturnsCorrectAction() {
        let result = matcher.match(keyCode: 123, modifiers: [.control, .option], bindings: bindings)
        #expect(result == .leftHalf)
    }

    @Test func exactMatchDifferentAction() {
        let result = matcher.match(keyCode: 124, modifiers: [.control, .option], bindings: bindings)
        #expect(result == .rightHalf)
    }

    @Test func missingModifierReturnsNil() {
        let result = matcher.match(keyCode: 123, modifiers: [.control], bindings: bindings)
        #expect(result == nil)
    }

    @Test func supersetModifiersReturnsNil() {
        let result = matcher.match(keyCode: 123, modifiers: [.control, .option, .shift], bindings: bindings)
        #expect(result == nil)
    }

    @Test func unknownKeycodeReturnsNil() {
        let result = matcher.match(keyCode: 999, modifiers: [.control, .option], bindings: bindings)
        #expect(result == nil)
    }

    @Test func emptyBindingsReturnsNil() {
        let result = matcher.match(keyCode: 123, modifiers: [.control, .option], bindings: [])
        #expect(result == nil)
    }

    @Test func wrongModifiersReturnsNil() {
        let result = matcher.match(keyCode: 123, modifiers: [.command, .shift], bindings: bindings)
        #expect(result == nil)
    }

    @Test func noModifiersReturnsNil() {
        let result = matcher.match(keyCode: 123, modifiers: [], bindings: bindings)
        #expect(result == nil)
    }

    @Test func showHintsActionMatches() {
        let bindings = [
            HotkeyBinding(modifiers: [.control, .option], keyCode: 0x2C, action: .showHints),
        ]
        let result = matcher.match(keyCode: 0x2C, modifiers: [.control, .option], bindings: bindings)
        #expect(result == .showHints)
    }
}
