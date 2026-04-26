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
        let flags = CGEventFlags([.maskAlphaShift, .maskNumericPad])
        let result = adapter.convertFlags(flags)
        #expect(result == ModifierSet())
    }
}
