import Testing
@testable import WindowManagerDomain

@Suite("Config")
struct ConfigTests {

    @Test func configWithBindingsAndGeneralSettings() {
        let bindings = [
            HotkeyBinding(modifiers: [.control, .option], keyCode: 123, action: .leftHalf),
            HotkeyBinding(modifiers: [.control, .option], keyCode: 124, action: .rightHalf),
        ]
        let general = GeneralConfig(padding: 8, animationDuration: 0.2)
        let config = Config(bindings: bindings, general: general)

        #expect(config.bindings.count == 2)
        #expect(config.bindings[0].action == .leftHalf)
        #expect(config.bindings[1].action == .rightHalf)
        #expect(config.general.padding == 8)
        #expect(config.general.animationDuration == 0.2)
    }

    @Test func defaultGeneralConfigValues() {
        let general = GeneralConfig()
        #expect(general.padding == 0)
        #expect(general.animationDuration == 0)
    }

    @Test func configWithDefaultGeneral() {
        let config = Config(bindings: [])
        #expect(config.bindings.isEmpty)
        #expect(config.general.padding == 0)
        #expect(config.general.animationDuration == 0)
    }

    @Test func modifierSetContains() {
        let mods: ModifierSet = [.control, .option, .command]
        #expect(mods.contains(.control))
        #expect(mods.contains(.option))
        #expect(mods.contains(.command))
        #expect(!mods.contains(.shift))
    }

    @Test func modifierSetSingleModifier() {
        let mods: ModifierSet = [.shift]
        #expect(mods.contains(.shift))
        #expect(!mods.contains(.control))
        #expect(!mods.contains(.option))
        #expect(!mods.contains(.command))
    }

    @Test func modifierSetEquality() {
        let a: ModifierSet = [.control, .option]
        let b: ModifierSet = [.option, .control]
        #expect(a == b)
    }

    @Test func hotkeyBindingEquality() {
        let a = HotkeyBinding(modifiers: [.control, .option], keyCode: 123, action: .leftHalf)
        let b = HotkeyBinding(modifiers: [.control, .option], keyCode: 123, action: .leftHalf)
        #expect(a == b)
    }
}
