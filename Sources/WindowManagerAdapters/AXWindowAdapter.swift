import AppKit
import ApplicationServices
import WindowManagerDomain

public final class AXWindowAdapter: WindowAccessPort, @unchecked Sendable {
    private let lock = NSLock()
    private var windowElements: [Int: AXUIElement] = [:]
    private var nextID: Int = 1
    private let screenInfo: any ScreenInfoPort & Sendable

    public init(screenInfo: any ScreenInfoPort & Sendable) {
        self.screenInfo = screenInfo
    }

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

        let start = DispatchTime.now()

        var pid: pid_t = 0
        let pidStatus = AXUIElementGetPid(element, &pid)
        let appEl: AXUIElement? = (pidStatus == .success && pid > 0)
            ? AXUIElementCreateApplication(pid)
            : nil

        // Bound AX message timeouts so a wedged target can't tie up this queue
        // (or hold the deferred EUI=true write hostage) for the 6s default.
        AXUIElementSetMessagingTimeout(element, 0.5)
        if let appEl {
            AXUIElementSetMessagingTimeout(appEl, 0.5)
        }

        let wasZoomed = getBoolAttribute(element, "AXZoomed")
        if wasZoomed {
            setBoolAttribute(element, "AXZoomed", false)
        }

        let wasEUI = appEl.map { getBoolAttribute($0, "AXEnhancedUserInterface") } ?? false
        if wasEUI, let appEl {
            setBoolAttribute(appEl, "AXEnhancedUserInterface", false)
            // Chromium rebuilds part of its AX tree on EUI flip; give it a tick.
            usleep(2_000)
        }
        // If the app process dies between here and the defer, EUI stays false
        // for the dead process — acceptable.
        defer {
            if wasEUI, let appEl {
                setBoolAttribute(appEl, "AXEnhancedUserInterface", true)
            }
        }

        var attempts = 0
        var ok = false
        for attempt in 0..<3 {
            if attempt > 0 {
                usleep(50_000)
            }
            attempts = attempt + 1

            let r1 = writePosition(element, position)
            let r2 = writeSize(element, size)
            let r3 = writePosition(element, position)

            if r1 == .success && r2 == .success && r3 == .success {
                ok = true
                break
            }
        }

        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        Log.windowOps.debug(
            "setWindowFrame pid=\(pid) wasEUI=\(wasEUI) wasZoomed=\(wasZoomed) attempts=\(attempts) result=\(ok ? "ok" : "failed") elapsedMs=\(String(format: "%.1f", elapsedMs))"
        )
        return ok
    }

    private func writePosition(_ element: AXUIElement, _ position: CGPoint) -> AXError {
        var pos = position
        guard let value = AXValueCreate(.cgPoint, &pos) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }

    private func writeSize(_ element: AXUIElement, _ size: CGSize) -> AXError {
        var sz = size
        guard let value = AXValueCreate(.cgSize, &sz) else { return .failure }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, value)
    }

    private func setBoolAttribute(_ element: AXUIElement, _ attribute: String, _ value: Bool) {
        let cfValue: CFBoolean = value ? kCFBooleanTrue : kCFBooleanFalse
        AXUIElementSetAttributeValue(element, attribute as CFString, cfValue)
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
        let screenID = screenInfo.screenContaining(point: position)?.id ?? 0

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

}
