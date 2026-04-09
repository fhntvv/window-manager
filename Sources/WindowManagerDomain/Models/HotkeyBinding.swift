public struct ModifierSet: OptionSet, Equatable, Hashable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let control = ModifierSet(rawValue: 1 << 0)
    public static let option  = ModifierSet(rawValue: 1 << 1)
    public static let command = ModifierSet(rawValue: 1 << 2)
    public static let shift   = ModifierSet(rawValue: 1 << 3)
}

public struct HotkeyBinding: Equatable, Sendable {
    public let modifiers: ModifierSet
    public let keyCode: UInt16
    public let action: WindowAction

    public init(modifiers: ModifierSet, keyCode: UInt16, action: WindowAction) {
        self.modifiers = modifiers
        self.keyCode = keyCode
        self.action = action
    }
}
