import CoreGraphics
@preconcurrency import os
import WindowManagerDomain

public final class CGEventTapAdapter: EventTapPort, @unchecked Sendable {
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    var handler: ((_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)?

    public init() {}

    deinit {
        stop()
    }

    public func start(handler: @escaping (_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool) {
        stop()
        self.handler = handler

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: cgEventTapCallback,
            userInfo: userInfo
        ) else {
            Log.eventTap.error("Failed to create event tap — hotkeys will not work")
            return
        }

        self.tapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        let rl = CFRunLoopGetCurrent()
        self.runLoop = rl
        CFRunLoopAddSource(rl, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.eventTap.info("Event tap created and enabled")
    }

    public func stop() {
        if let source = runLoopSource, let rl = runLoop {
            CFRunLoopRemoveSource(rl, source, .commonModes)
        }
        if let tap = tapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            Log.eventTap.info("Event tap stopped")
        }
        tapPort = nil
        runLoopSource = nil
        runLoop = nil
        handler = nil
    }

    public func ensureEnabled() {
        guard let tap = tapPort else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            Log.eventTap.warning("Event tap was disabled by system — re-enabling")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Log.eventTap.warning("Event tap disabled by \(type == .tapDisabledByTimeout ? "timeout" : "user input", privacy: .public) — re-enabling")
            ensureEnabled()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let handler else {
            return Unmanaged.passUnretained(event)
        }

        let rawFlags = event.flags
        // Early bail: skip events without at least one modifier held.
        // Avoids processing plain keystrokes entirely.
        guard rawFlags.contains(.maskControl) || rawFlags.contains(.maskCommand) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = convertFlags(rawFlags)

        if handler(keyCode, modifiers) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    func convertFlags(_ flags: CGEventFlags) -> ModifierSet {
        var result = ModifierSet()
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }
}

private func cgEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let adapter = Unmanaged<CGEventTapAdapter>.fromOpaque(userInfo).takeUnretainedValue()
    return adapter.handleEvent(type: type, event: event)
}
