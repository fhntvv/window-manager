import AppKit
import WindowManagerAdapters
import WindowManagerDomain

@MainActor
final class AppCompositionRoot {
    private let eventTap: CGEventTapAdapter
    private let windowService: WindowOperationService
    private let config: Config
    private let hotkeyMatcher: HotkeyMatcher
    private var healthCheckTimer: Timer?

    init() throws {
        Self.waitForAccessibility()

        let configAdapter = TOMLConfigAdapter()
        do {
            self.config = try configAdapter.loadConfig()
        } catch {
            fputs("Warning: failed to load config: \(error). Using defaults.\n", stderr)
            self.config = Config(bindings: [], general: GeneralConfig())
        }

        let windowAccess = AXWindowAdapter()
        let screenInfo = NSScreenAdapter()
        self.eventTap = CGEventTapAdapter()
        self.hotkeyMatcher = HotkeyMatcher()

        self.windowService = WindowOperationService(
            windowAccess: windowAccess,
            screenInfo: screenInfo,
            padding: config.general.padding
        )
    }

    func run() {
        let bindings = config.bindings
        let matcher = hotkeyMatcher
        let service = windowService

        eventTap.start { keyCode, modifiers in
            guard let action = matcher.match(keyCode: keyCode, modifiers: modifiers, bindings: bindings) else {
                return false
            }
            service.execute(action)
            return true
        }

        startHealthCheckTimer()

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
    }

    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.eventTap.ensureEnabled()
        }
    }

    private static nonisolated func waitForAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            return
        }

        while !AXIsProcessTrusted() {
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
}
