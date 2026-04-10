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
        if Thread.isMainThread {
            return NSScreen.screens.first?.frame.height ?? 0
        }
        return DispatchQueue.main.sync {
            NSScreen.screens.first?.frame.height ?? 0
        }
    }

    private func invalidateCache() {
        lock.lock()
        cachedScreens = nil
        lock.unlock()
    }

    private func buildScreenInfos() -> [ScreenInfo] {
        let screenData: [(frame: CGRect, visibleFrame: CGRect, displayID: Int)]
        if Thread.isMainThread {
            screenData = NSScreen.screens.map { screen in
                (frame: screen.frame, visibleFrame: screen.visibleFrame, displayID: screenDisplayID(screen))
            }
        } else {
            screenData = DispatchQueue.main.sync {
                NSScreen.screens.map { screen in
                    (frame: screen.frame, visibleFrame: screen.visibleFrame, displayID: screenDisplayID(screen))
                }
            }
        }

        let primaryHeight = screenData.first?.frame.height ?? 0

        return screenData.enumerated().map { index, data in
            let frameAX = convertToAX(rect: data.frame, primaryHeight: primaryHeight)
            let visibleFrameAX = convertToAX(rect: data.visibleFrame, primaryHeight: primaryHeight)
            return ScreenInfo(
                id: data.displayID,
                frame: frameAX,
                visibleFrame: visibleFrameAX,
                isPrimary: index == 0
            )
        }
    }

    private func convertToAX(rect: NSRect, primaryHeight: CGFloat) -> CGRect {
        let axY = primaryHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: axY, width: rect.width, height: rect.height)
    }
}

private func screenDisplayID(_ screen: NSScreen) -> Int {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return screen.deviceDescription[key] as? Int ?? 0
}
