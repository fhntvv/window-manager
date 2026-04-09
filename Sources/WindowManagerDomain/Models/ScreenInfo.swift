import Foundation

public struct ScreenInfo: Sendable {
    public let id: Int
    public let frame: CGRect
    public let visibleFrame: CGRect
    public let isPrimary: Bool

    public init(id: Int, frame: CGRect, visibleFrame: CGRect, isPrimary: Bool) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
        self.isPrimary = isPrimary
    }
}
