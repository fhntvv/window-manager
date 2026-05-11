import AppKit
import WindowManagerAdapters
import WindowManagerDomain

@MainActor
final class AppCompositionRoot {
    private let eventTap: CGEventTapAdapter
    private let windowService: WindowOperationService
    private let config: Config
    private let hotkeyMatcher: HotkeyMatcher
    private let hintOverlay: HintOverlayPanel
    private var healthCheckTimer: Timer?
    private let operationQueue = DispatchQueue(label: "windowmanager.operations", qos: .userInteractive)
    private let logger = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")

    init() throws {
        Self.logStartupIdentity(logger: logger)
        Self.enforceSingleton(logger: logger)
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
        self.hintOverlay = HintOverlayPanel()

        logger.info("WindowManager initialized — \(self.config.bindings.count) bindings loaded")
        Self.logCheatSheet(config.bindings, logger: logger)
    }

    private static nonisolated func logStartupIdentity(logger: DebugLogger) {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
        let executable = Bundle.main.executablePath ?? CommandLine.arguments.first ?? "?"
        let bundle = Bundle.main.bundlePath
        logger.info("startup version=\(version) pid=\(getpid()) executable=\(executable) bundle=\(bundle)")
    }

    private static nonisolated func enforceSingleton(logger: DebugLogger) {
        let fm = FileManager.default
        let supportDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.windowmanager", isDirectory: true)
        let pidFile = supportDir.appendingPathComponent("instance.pid")

        try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)

        if let existing = try? String(contentsOf: pidFile, encoding: .utf8),
           let otherPid = pid_t(existing.trimmingCharacters(in: .whitespacesAndNewlines)),
           otherPid > 0,
           kill(otherPid, 0) == 0 {
            logger.fault("another windowmanager is already running (pid=\(otherPid)) — exiting")
            fputs("fatal: another windowmanager is already running (pid=\(otherPid))\n", stderr)
            exit(1)
        }

        try? "\(getpid())".write(to: pidFile, atomically: true, encoding: .utf8)
        atexit_b {
            try? FileManager.default.removeItem(at: pidFile)
        }
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
        let overlay = hintOverlay

        let log = DebugLogger(subsystem: "com.windowmanager", category: "EventTap")
        eventTap.start { keyCode, modifiers in
            guard let action = matcher.match(keyCode: keyCode, modifiers: modifiers, bindings: bindings) else {
                return false
            }
            log.info("Hotkey matched: \(action.rawValue)")
            guard action != .showHints else {
                DispatchQueue.main.async {
                    overlay.toggle(bindings: bindings)
                }
                return true
            }
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
        let logger = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            return
        }

        var iteration = 0
        while !AXIsProcessTrusted() {
            if iteration % 5 == 0 {
                logger.warning("Waiting for Accessibility permission — grant in System Settings → Privacy & Security → Accessibility, then ensure the app is launched via Launch Services (open / Finder / LaunchAgent), not directly from a terminal")
            }
            iteration += 1
            Thread.sleep(forTimeInterval: 1.0)
        }
        logger.info("Accessibility permission granted — continuing startup")
    }
}
