import Foundation

public protocol ScreenInfoPort {
    func allScreens() -> [ScreenInfo]
    func screenContaining(point: CGPoint) -> ScreenInfo?
    func primaryScreenHeight() -> CGFloat
}
