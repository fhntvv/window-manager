public struct HotkeyMatcher: Sendable {

    public init() {}

    public func match(
        keyCode: UInt16,
        modifiers: ModifierSet,
        bindings: [HotkeyBinding]
    ) -> WindowAction? {
        for binding in bindings {
            if binding.keyCode == keyCode && binding.modifiers == modifiers {
                return binding.action
            }
        }
        return nil
    }
}
