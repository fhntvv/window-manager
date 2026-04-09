import AppKit
import ApplicationServices
import WindowManagerDomain

public final class AXWindowAdapter: WindowAccessPort, @unchecked Sendable {
    private let lock = NSLock()
    private var windowElements: [Int: AXUIElement] = [:]
    private var nextID: Int = 1

    public init() {}

    public func getFocusedWindow() -> WindowInfo? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success else {
            return nil
        }

        let appElement = focusedApp as! AXUIElement

        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success else {
            return nil
        }

        let windowElement = focusedWindow as! AXUIElement
        return windowInfo(from: windowElement)
    }

    public func setWindowFrame(_ window: WindowManagerDomain.WindowRef, position: CGPoint, size: CGSize) -> Bool {
        lock.lock()
        let element = windowElements[window.id]
        lock.unlock()

        guard let element else { return false }

        for attempt in 0..<3 {
            if attempt > 0 {
                usleep(50_000)
            }

            var pos = position
            guard let posValue = AXValueCreate(.cgPoint, &pos) else { continue }
            let posResult = AXUIElementSetAttributeValue(
                element,
                kAXPositionAttribute as CFString,
                posValue
            )

            var sz = size
            guard let sizeValue = AXValueCreate(.cgSize, &sz) else { continue }
            let sizeResult = AXUIElementSetAttributeValue(
                element,
                kAXSizeAttribute as CFString,
                sizeValue
            )

            if posResult == .success && sizeResult == .success {
                return true
            }
        }

        return false
    }

    public func getWindowInfo(_ window: WindowManagerDomain.WindowRef) -> WindowInfo? {
        lock.lock()
        let element = windowElements[window.id]
        lock.unlock()

        guard let element else { return nil }
        return buildWindowInfo(from: element, existingID: window.id)
    }

    private func windowInfo(from element: AXUIElement) -> WindowInfo? {
        let id = storeElement(element)
        return buildWindowInfo(from: element, existingID: id)
    }

    private func buildWindowInfo(from element: AXUIElement, existingID: Int) -> WindowInfo? {
        guard let position = getPointAttribute(element, kAXPositionAttribute),
              let size = getSizeAttribute(element, kAXSizeAttribute)
        else {
            return nil
        }

        let isFullscreen = getBoolAttribute(element, "AXFullScreen")
        let screenID = determineScreenID(for: position)

        return WindowInfo(
            ref: WindowManagerDomain.WindowRef(id: existingID),
            position: position,
            size: size,
            screenID: screenID,
            isFullscreen: isFullscreen
        )
    }

    private func storeElement(_ element: AXUIElement) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let id = nextID
        nextID += 1
        windowElements[id] = element
        if windowElements.count > 64 {
            let threshold = id - 8
            windowElements = windowElements.filter { $0.key > threshold }
        }
        return id
    }

    private func getPointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value
        else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func getSizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let axValue = value
        else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(axValue as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private func determineScreenID(for position: CGPoint) -> Int {
        let screenData: [(frame: CGRect, displayID: Int)]
        if Thread.isMainThread {
            screenData = NSScreen.screens.map { screen in
                (frame: screen.frame, displayID: screenDisplayID(screen))
            }
        } else {
            screenData = DispatchQueue.main.sync {
                NSScreen.screens.map { screen in
                    (frame: screen.frame, displayID: screenDisplayID(screen))
                }
            }
        }

        let primaryHeight = screenData.first?.frame.height ?? 0

        for data in screenData {
            let axY = primaryHeight - data.frame.origin.y - data.frame.height
            let axFrame = CGRect(
                x: data.frame.origin.x,
                y: axY,
                width: data.frame.width,
                height: data.frame.height
            )
            if axFrame.contains(position) {
                return data.displayID
            }
        }

        return screenData.first?.displayID ?? 0
    }
}

func screenDisplayID(_ screen: NSScreen) -> Int {
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    return screen.deviceDescription[key] as? Int ?? 0
}
