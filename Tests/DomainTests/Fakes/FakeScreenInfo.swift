import Foundation
@testable import WindowManagerDomain

final class FakeScreenInfo: ScreenInfoPort, @unchecked Sendable {
    var screens: [ScreenInfo] = []
    var _primaryScreenHeight: CGFloat = 1080

    func allScreens() -> [ScreenInfo] {
        screens
    }

    func screenContaining(point: CGPoint) -> ScreenInfo? {
        screens.first { screen in
            let f = screen.frame
            return point.x >= f.origin.x && point.x < f.origin.x + f.size.width
                && point.y >= f.origin.y && point.y < f.origin.y + f.size.height
        }
    }

    func primaryScreenHeight() -> CGFloat {
        _primaryScreenHeight
    }
}
