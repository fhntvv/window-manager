import AppKit
import ApplicationServices
import WindowManagerAdapters
import WindowManagerDomain

@MainActor
final class AppCompositionRoot {
    private let config: Config
    private let hotkeyMatcher: HotkeyMatcher
    private let hintOverlay: HintOverlayPanel
    private let screenInfo: NSScreenAdapter
    private let operationQueue = DispatchQueue(label: "windowmanager.operations", qos: .userInteractive)
    private let logger = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")

    private var eventTap: CGEventTapAdapter?
    private var windowService: WindowOperationService?
    private var healthCheckTimer: Timer?
    private var tccWatcher: DispatchSourceFileSystemObject?
    private var trustPollTimer: Timer?

    init() throws {
        Self.logStartupIdentity(logger: logger)
        Self.enforceSingleton(logger: logger)

        let configAdapter = TOMLConfigAdapter()
        do {
            self.config = try configAdapter.loadConfig()
        } catch {
            fputs("Warning: failed to load config: \(error). Using defaults.\n", stderr)
            self.config = TOMLConfigAdapter.defaultConfig
        }

        self.screenInfo = NSScreenAdapter()
        self.hotkeyMatcher = HotkeyMatcher()
        self.hintOverlay = HintOverlayPanel()

        logger.info("WindowManager initialized — \(self.config.bindings.count) bindings loaded")
        Self.logCheatSheet(config.bindings, logger: logger)
    }

    func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        startWhenTrusted()
        app.run()
    }

    private func startWhenTrusted() {
        let promptOptions = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if AXIsProcessTrustedWithOptions(promptOptions) {
            startTrustedServices()
            return
        }

        logger.info("waiting for Accessibility permission — will resume automatically when granted")
        installTCCWatcher()
        installTrustPollTimer()
    }

    private func installTCCWatcher() {
        let tccDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.TCC", isDirectory: true)
        let fd = open(tccDir.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.warning("could not open TCC dir for watching (errno=\(errno)) — falling back to timer-only")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.checkAndStartIfTrusted() }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.tccWatcher = source
    }

    private func installTrustPollTimer() {
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkAndStartIfTrusted() }
        }
    }

    private func checkAndStartIfTrusted() {
        guard AXIsProcessTrusted() else { return }
        tccWatcher?.cancel()
        tccWatcher = nil
        trustPollTimer?.invalidate()
        trustPollTimer = nil
        startTrustedServices()
    }

    private func startTrustedServices() {
        guard eventTap == nil else { return }

        let windowAccess = AXWindowAdapter(screenInfo: screenInfo)
        let service = WindowOperationService(
            windowAccess: windowAccess,
            screenInfo: screenInfo,
            padding: config.general.padding
        )
        let tap = CGEventTapAdapter()

        self.windowService = service
        self.eventTap = tap

        let bindings = config.bindings
        let matcher = hotkeyMatcher
        let queue = operationQueue
        let overlay = hintOverlay
        let log = DebugLogger(subsystem: "com.windowmanager", category: "EventTap")

        tap.start { keyCode, modifiers in
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
        logger.info("Accessibility granted — services started")
    }

    private func startHealthCheckTimer() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.eventTap?.ensureEnabled() }
        }
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
}
