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
    private let operationQueue = DispatchQueue(label: "windowmanager.operations", qos: .userInteractive)
    private let logger = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")

    init() throws {
        Self.waitForAccessibility()

        let configAdapter = TOMLConfigAdapter()
        do {
            self.config = try configAdapter.loadConfig()
        } catch {
            fputs("Warning: failed to load config: \(error). Using defaults.\n", stderr)
            self.config = TOMLConfigAdapter.defaultConfig
        }

        let screenInfo = NSScreenAdapter()
        let windowAccess = AXWindowAdapter(screenInfo: screenInfo)
        self.eventTap = CGEventTapAdapter()
        self.hotkeyMatcher = HotkeyMatcher()

        self.windowService = WindowOperationService(
            windowAccess: windowAccess,
            screenInfo: screenInfo,
            padding: config.general.padding
        )

        logger.info("WindowManager initialized — \(self.config.bindings.count) bindings loaded")
        Self.logCheatSheet(config.bindings, logger: logger)
    }

    private static func logCheatSheet(_ bindings: [HotkeyBinding], logger: DebugLogger) {
        logger.info("=== Hotkey cheat sheet ===")
        for binding in bindings {
            let mods = TOMLConfigAdapter.formatModifiers(binding.modifiers)
            let key = TOMLConfigAdapter.keyName(for: binding.keyCode)
            logger.info("  \(mods)+\(key) → \(binding.action.rawValue)")
        }
    }

    func run() {
        let bindings = config.bindings
        let matcher = hotkeyMatcher
        let service = windowService
        let queue = operationQueue

        let log = DebugLogger(subsystem: "com.windowmanager", category: "EventTap")
        eventTap.start { keyCode, modifiers in
            guard let action = matcher.match(keyCode: keyCode, modifiers: modifiers, bindings: bindings) else {
                return false
            }
            log.info("Hotkey matched: \(action.rawValue)")
            queue.async {
                service.execute(action)
            }
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
