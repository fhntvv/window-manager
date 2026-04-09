import Foundation

public protocol WindowAccessPort {
    func getFocusedWindow() -> WindowInfo?
    func setWindowFrame(_ window: WindowRef, position: CGPoint, size: CGSize) -> Bool
    func getWindowInfo(_ window: WindowRef) -> WindowInfo?
}
