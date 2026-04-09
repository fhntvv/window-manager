public protocol EventTapPort {
    func start(handler: @escaping (_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)
    func stop()
    func ensureEnabled()
}
