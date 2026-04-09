import CoreGraphics
import WindowManagerDomain

public final class CGEventTapAdapter: EventTapPort, @unchecked Sendable {
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool)?

    public init() {}

    public func start(handler: @escaping (_ keyCode: UInt16, _ modifiers: ModifierSet) -> Bool) {
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
            return
        }

        self.tapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    public func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = tapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        tapPort = nil
        runLoopSource = nil
        handler = nil
    }

    public func ensureEnabled() {
        guard let tap = tapPort else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            ensureEnabled()
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown, let handler else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = convertFlags(event.flags)

        if handler(keyCode, modifiers) {
            return nil
        }

        return Unmanaged.passUnretained(event)
    }

    private func convertFlags(_ flags: CGEventFlags) -> ModifierSet {
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
