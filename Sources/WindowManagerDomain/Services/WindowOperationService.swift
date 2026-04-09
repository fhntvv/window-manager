import Foundation

public final class WindowOperationService: Sendable {
    private let windowAccess: any WindowAccessPort & Sendable
    private let screenInfo: any ScreenInfoPort & Sendable
    private let tilingEngine: TilingEngine
    private let padding: CGFloat

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
        guard let window = windowAccess.getFocusedWindow() else { return }
        guard !window.isFullscreen else { return }

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
        _ = windowAccess.setWindowFrame(window.ref, position: frame.origin, size: frame.size)
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
        let smallSize = CGSize(width: 100, height: 100)
        _ = windowAccess.setWindowFrame(window.ref, position: window.position, size: smallSize)
        _ = windowAccess.setWindowFrame(window.ref, position: targetFrame.origin, size: smallSize)
        _ = windowAccess.setWindowFrame(window.ref, position: targetFrame.origin, size: targetFrame.size)
    }
}
