import AppKit
import WindowManagerDomain

public final class NSScreenAdapter: ScreenInfoPort, @unchecked Sendable {
    private let lock = NSLock()
    private var cachedScreens: [ScreenInfo]?
    private var observer: NSObjectProtocol?

    public init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.invalidateCache()
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    public func allScreens() -> [ScreenInfo] {
        lock.lock()
        if let cached = cachedScreens {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let screens = buildScreenInfos()

        lock.lock()
        cachedScreens = screens
        lock.unlock()

        return screens
    }

    public func screenContaining(point: CGPoint) -> ScreenInfo? {
        allScreens().first { $0.frame.contains(point) }
    }

    public func primaryScreenHeight() -> CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    private func invalidateCache() {
        lock.lock()
        cachedScreens = nil
        lock.unlock()
    }

    private func buildScreenInfos() -> [ScreenInfo] {
        let nsScreens = NSScreen.screens
        let primaryHeight = nsScreens.first?.frame.height ?? 0

        return nsScreens.map { screen in
            let displayID = screenDisplayID(screen)
            let isPrimary = screen == nsScreens.first

            let frameAX = convertToAX(rect: screen.frame, primaryHeight: primaryHeight)
            let visibleFrameAX = convertToAX(rect: screen.visibleFrame, primaryHeight: primaryHeight)

            return ScreenInfo(
                id: displayID,
                frame: frameAX,
                visibleFrame: visibleFrameAX,
                isPrimary: isPrimary
            )
        }
    }

    private func convertToAX(rect: NSRect, primaryHeight: CGFloat) -> CGRect {
        let axY = primaryHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: axY, width: rect.width, height: rect.height)
    }
}
