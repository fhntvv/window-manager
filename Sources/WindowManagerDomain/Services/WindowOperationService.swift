import Foundation
import os

public final class WindowOperationService: Sendable {
    private let windowAccess: any WindowAccessPort & Sendable
    private let screenInfo: any ScreenInfoPort & Sendable
    private let tilingEngine: TilingEngine
    private let padding: CGFloat
    private let logger = Logger(subsystem: "com.windowmanager", category: "WindowOps")

    public init(
        windowAccess: any WindowAccessPort & Sendable,
        screenInfo: any ScreenInfoPort & Sendable,
        tilingEngine: TilingEngine = TilingEngine(),
        padding: CGFloat = 0
    ) {
        self.windowAccess = windowAccess
        self.screenInfo = screenInfo
        self.tilingEngine = tilingEngine
        self.padding = padding
    }

    public func execute(_ action: WindowAction) {
        guard let window = windowAccess.getFocusedWindow() else {
            logger.debug("No focused window — skipping \(action.rawValue, privacy: .public)")
            return
        }
        guard !window.isFullscreen else {
            logger.debug("Window is fullscreen — skipping \(action.rawValue, privacy: .public)")
            return
        }

        switch action {
        case .nextDisplay:
            executeDisplayMove(window: window, direction: 1)
        case .prevDisplay:
            executeDisplayMove(window: window, direction: -1)
        default:
            executeSingleScreen(action: action, window: window)
        }
    }

    private func executeSingleScreen(action: WindowAction, window: WindowInfo) {
        let screens = screenInfo.allScreens()
        guard let screen = screens.first(where: { $0.id == window.screenID })
            ?? screenInfo.screenContaining(point: window.position)
            ?? screens.first
        else { return }

        let frame = tilingEngine.computeFrame(
            action: action,
            screen: screen,
            currentWindow: window,
            padding: padding
        )
        let ok = windowAccess.setWindowFrame(window.ref, position: frame.origin, size: frame.size)
        logger.info("\(action.rawValue, privacy: .public) → frame(\(frame.origin.x, privacy: .public), \(frame.origin.y, privacy: .public), \(frame.size.width, privacy: .public), \(frame.size.height, privacy: .public)) — \(ok ? "ok" : "failed", privacy: .public)")
    }

    private func executeDisplayMove(window: WindowInfo, direction: Int) {
        let screens = screenInfo.allScreens()
        guard screens.count > 1 else { return }

        guard let currentIndex = screens.firstIndex(where: { $0.id == window.screenID }) else { return }

        let nextIndex = (currentIndex + direction + screens.count) % screens.count
        let targetScreen = screens[nextIndex]

        let targetFrame = tilingEngine.computeFrame(
            action: .maximize,
            screen: targetScreen,
            currentWindow: window,
            padding: padding
        )

        // Triple-write: shrink → move → resize
        let shrunkSize = CGSize(
            width: min(window.size.width, targetScreen.visibleFrame.size.width),
            height: min(window.size.height, targetScreen.visibleFrame.size.height)
        )
        _ = windowAccess.setWindowFrame(window.ref, position: window.position, size: shrunkSize)
        _ = windowAccess.setWindowFrame(window.ref, position: targetFrame.origin, size: shrunkSize)
        let ok = windowAccess.setWindowFrame(window.ref, position: targetFrame.origin, size: targetFrame.size)
        let actionName = direction > 0 ? "nextDisplay" : "prevDisplay"
        logger.info("\(actionName, privacy: .public) → screen \(nextIndex, privacy: .public), frame(\(targetFrame.origin.x, privacy: .public), \(targetFrame.origin.y, privacy: .public), \(targetFrame.size.width, privacy: .public), \(targetFrame.size.height, privacy: .public)) — \(ok ? "ok" : "failed", privacy: .public)")
    }
}
