import Foundation

public struct WindowInfo: Sendable {
    public let ref: WindowRef
    public let position: CGPoint
    public let size: CGSize
    public let screenID: Int
    public let isFullscreen: Bool

    public init(ref: WindowRef, position: CGPoint, size: CGSize, screenID: Int, isFullscreen: Bool) {
        self.ref = ref
        self.position = position
        self.size = size
        self.screenID = screenID
        self.isFullscreen = isFullscreen
    }
}
