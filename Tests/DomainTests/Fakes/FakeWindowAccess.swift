import Foundation
@testable import WindowManagerDomain

final class FakeWindowAccess: WindowAccessPort, @unchecked Sendable {
    var focusedWindow: WindowInfo?
    var windowInfoByRef: [WindowRef: WindowInfo] = [:]
    var setFrameCalls: [(window: WindowRef, position: CGPoint, size: CGSize)] = []
    var setFrameReturnValue: Bool = true

    func getFocusedWindow() -> WindowInfo? {
        focusedWindow
    }

    func setWindowFrame(_ window: WindowRef, position: CGPoint, size: CGSize) -> Bool {
        setFrameCalls.append((window: window, position: position, size: size))
        return setFrameReturnValue
    }

    func getWindowInfo(_ window: WindowRef) -> WindowInfo? {
        windowInfoByRef[window]
    }
}
