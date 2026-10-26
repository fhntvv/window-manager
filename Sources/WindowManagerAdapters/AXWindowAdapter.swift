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
        // Use NSWorkspace as source of truth for foreground app — it works even
        // when Chrome's AX tree is lazy-uninitialized and the systemwide AX
        // query returns kAXErrorNoValue.
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            Log.windowOps.error("getFocusedWindow failed: NSWorkspace has no frontmost application")
            return nil
        }
        let pid = frontApp.processIdentifier
        let bundle = frontApp.bundleIdentifier ?? "?"
        let name = frontApp.localizedName ?? "?"
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.5)

        var focusedWindow: CFTypeRef?
        let firstAXError = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        )
        var result = firstAXError

        var wake: FocusedWindowLogRecord.Wake?
        if firstAXError != .success {
            // Chrome / Chromium-based apps lazy-initialize their AX tree.
            // Set both wake-up flags and give Chromium time to populate.
            let manualAXWrite = AXUIElementSetAttributeValue(
                appElement,
                "AXManualAccessibility" as CFString,
                kCFBooleanTrue
            )
            let euiWrite = AXUIElementSetAttributeValue(
                appElement,
                "AXEnhancedUserInterface" as CFString,
                kCFBooleanTrue
            )
            usleep(100_000)
            result = AXUIElementCopyAttributeValue(
                appElement,
                kAXFocusedWindowAttribute as CFString,
                &focusedWindow
            )
            wake = .init(manualAXWrite: manualAXWrite, euiWrite: euiWrite, retryAXError: result)
        }

        func log(_ outcome: FocusedWindowLogRecord.Outcome) {
            emit(FocusedWindowLogRecord(
                pid: pid,
                bundle: bundle,
                name: name,
                firstAXError: firstAXError,
                wake: wake,
                outcome: outcome
            ))
        }

        guard result == .success else {
            log(.readFailed(callerTrusted: AXIsProcessTrusted()))
            return nil
        }
        guard let focusedWindow else {
            log(.missingFocusedWindow(callerTrusted: AXIsProcessTrusted()))
            return nil
        }

        let windowElement = focusedWindow as! AXUIElement
        switch windowInfo(from: windowElement) {
        case let .success(info):
            log(.ok)
            return info
        case let .failure(failure):
            log(.windowUnreadable(failure, callerTrusted: AXIsProcessTrusted()))
            return nil
        }
    }

    public func setWindowFrame(_ window: WindowManagerDomain.WindowRef, position: CGPoint, size: CGSize) -> Bool {
        lock.lock()
        let element = windowElements[window.id]
        lock.unlock()

        guard let element else {
            Log.windowOps.error("setWindowFrame failed: no element for window ref \(window.id)")
            return false
        }

        let start = DispatchTime.now()

        var pid: pid_t = 0
        let pidStatus = AXUIElementGetPid(element, &pid)
        let appEl: AXUIElement? = (pidStatus == .success && pid > 0)
            ? AXUIElementCreateApplication(pid)
            : nil

        // Bound AX message timeouts so a wedged target can't tie up this queue
        // (or hold the EUI=true restore hostage) for the 6s default.
        AXUIElementSetMessagingTimeout(element, 0.5)
        if let appEl {
            AXUIElementSetMessagingTimeout(appEl, 0.5)
        }

        let wasZoomed = getBoolAttribute(element, "AXZoomed")
        if wasZoomed {
            _ = setBoolAttribute(element, "AXZoomed", false)
        }

        let euiRead = appEl.map { readBoolAttribute($0, "AXEnhancedUserInterface") }
        let wasEUI = euiRead?.value ?? false
        var euiOffAXError = AXError.success
        if wasEUI, let appEl {
            euiOffAXError = setBoolAttribute(appEl, "AXEnhancedUserInterface", false)
            // Chromium rebuilds part of its AX tree on EUI flip; give it a tick.
            usleep(2_000)
        }
        // If the app process dies between here and the restore, EUI stays false
        // for the dead process — acceptable.

        var attempts: [WindowFrameLogRecord.Attempt] = []
        var ok = false
        for attempt in 0..<3 {
            if attempt > 0 {
                usleep(50_000)
            }

            let r1 = writePosition(element, position)
            let r2 = writeSize(element, size)
            let r3 = writePosition(element, position)
            attempts.append(.init(position: r1, size: r2, positionAgain: r3))

            if r1 == .success && r2 == .success && r3 == .success {
                ok = true
                break
            }
        }

        var flip: WindowFrameLogRecord.Flip?
        if wasEUI, let appEl {
            let restoreAXError = setBoolAttribute(appEl, "AXEnhancedUserInterface", true)
            flip = .init(offAXError: euiOffAXError, restoreAXError: restoreAXError)
        }

        let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        emit(WindowFrameLogRecord(
            pid: pid,
            pidAXError: pidStatus,
            eui: euiRead.map { .init(readAXError: $0.error, flip: flip) },
            wasZoomed: wasZoomed,
            attempts: attempts,
            ok: ok,
            elapsedMs: elapsedMs
        ))
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

    private func setBoolAttribute(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> AXError {
        let cfValue: CFBoolean = value ? kCFBooleanTrue : kCFBooleanFalse
        return AXUIElementSetAttributeValue(element, attribute as CFString, cfValue)
    }

    private func emit(_ record: FocusedWindowLogRecord) {
        emit(record.message, isFailure: record.isFailure)
    }

    private func emit(_ record: WindowFrameLogRecord) {
        emit(record.message, isFailure: record.isFailure)
    }

    private func emit(_ message: String, isFailure: Bool) {
        if isFailure {
            Log.windowOps.error(message)
        } else {
            Log.windowOps.notice(message)
        }
    }

    public func getWindowInfo(_ window: WindowManagerDomain.WindowRef) -> WindowInfo? {
        lock.lock()
        let element = windowElements[window.id]
        lock.unlock()

        guard let element else { return nil }
        return try? buildWindowInfo(from: element, existingID: window.id).get()
    }

    private func windowInfo(from element: AXUIElement) -> Result<WindowInfo, AttributeReadFailure> {
        let id = storeElement(element)
        return buildWindowInfo(from: element, existingID: id)
    }

    private func buildWindowInfo(from element: AXUIElement, existingID: Int) -> Result<WindowInfo, AttributeReadFailure> {
        getPointAttribute(element, kAXPositionAttribute).flatMap { position in
            getSizeAttribute(element, kAXSizeAttribute).map { size in
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
        }
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

    private func getPointAttribute(_ element: AXUIElement, _ attribute: String) -> Result<CGPoint, AttributeReadFailure> {
        copyAXValue(element, attribute).flatMap { axValue in
            var point = CGPoint.zero
            guard AXValueGetValue(axValue, .cgPoint, &point) else { return .failure(.decodeFailed(attribute: attribute)) }
            return .success(point)
        }
    }

    private func getSizeAttribute(_ element: AXUIElement, _ attribute: String) -> Result<CGSize, AttributeReadFailure> {
        copyAXValue(element, attribute).flatMap { axValue in
            var size = CGSize.zero
            guard AXValueGetValue(axValue, .cgSize, &size) else { return .failure(.decodeFailed(attribute: attribute)) }
            return .success(size)
        }
    }

    private func copyAXValue(_ element: AXUIElement, _ attribute: String) -> Result<AXValue, AttributeReadFailure> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return .failure(.readFailed(attribute: attribute, error: error)) }
        guard let axValue = value else { return .failure(.missingValue(attribute: attribute)) }
        return .success(axValue as! AXValue)
    }

    private func getBoolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool {
        readBoolAttribute(element, attribute).value
    }

    private func readBoolAttribute(_ element: AXUIElement, _ attribute: String) -> (value: Bool, error: AXError) {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return (false, error)
        }
        return ((value as? Bool) ?? false, error)
    }

}
