import Testing
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("TOMLConfigAdapter – utility functions")
struct TOMLConfigAdapterUtilTests {

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

    @Test func keyNameForLeftArrow() {
        let result = TOMLConfigAdapter.keyName(for: 0x7B)
        #expect(result == "left")
    }

    @Test func keyNameForReturnKey() {
        let result = TOMLConfigAdapter.keyName(for: 0x24)
        #expect(result == "return")
    }

    @Test func keyNameForEscapeKey() {
        let result = TOMLConfigAdapter.keyName(for: 0x35)
        #expect(result == "escape")
    }

    @Test func keyNameForUnknownKeycodeReturnsHex() {
        let result = TOMLConfigAdapter.keyName(for: 0xFF)
        #expect(result == "0xFF")
    }

    @Test func keyNameForLetterA() {
        let result = TOMLConfigAdapter.keyName(for: 0x00)
        #expect(result == "a")
    }

    @Test func keyNameForSlash() {
        let result = TOMLConfigAdapter.keyName(for: 0x2C)
        #expect(result == "/")
    }
}
