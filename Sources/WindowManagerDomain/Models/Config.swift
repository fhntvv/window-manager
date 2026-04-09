import Foundation

public struct GeneralConfig: Equatable, Sendable {
    public let padding: CGFloat
    public let animationDuration: Double

    public init(padding: CGFloat = 0, animationDuration: Double = 0) {
        self.padding = padding
        self.animationDuration = animationDuration
    }
}

public struct Config: Equatable, Sendable {
    public let bindings: [HotkeyBinding]
    public let general: GeneralConfig

    public init(bindings: [HotkeyBinding], general: GeneralConfig = GeneralConfig()) {
        self.bindings = bindings
        self.general = general
    }
}
