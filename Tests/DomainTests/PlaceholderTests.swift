import Testing
@testable import WindowManagerDomain

@Test func domainModelsExist() {
    let ref = WindowRef(id: 1)
    #expect(ref.id == 1)

    let action = WindowAction.leftHalf
    #expect(action == .leftHalf)

    let modifiers: ModifierSet = [.control, .option]
    #expect(modifiers.contains(.control))
    #expect(modifiers.contains(.option))
    #expect(!modifiers.contains(.command))

    let config = Config(bindings: [])
    #expect(config.bindings.isEmpty)
    #expect(config.general.padding == 0)
}
