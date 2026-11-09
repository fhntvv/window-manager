import ApplicationServices
import Foundation
import WindowManagerDomain

@MainActor
enum AccessibilityReset {
    private static let lastResetBuildKey = "AccessibilityReset.lastResetBuild"

    static func runOnceIfNeeded(logger: DebugLogger) {
        guard Bundle.main.bundlePath.hasSuffix(".app"),
              let bundleID = Bundle.main.bundleIdentifier
        else { return }

        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let defaults = UserDefaults.standard
        let shouldReset = AccessibilityResetPolicy.shouldReset(
            isTrusted: AXIsProcessTrusted(),
            build: build,
            lastResetBuild: defaults.string(forKey: lastResetBuildKey)
        )
        guard shouldReset else { return }

        defaults.set(build, forKey: lastResetBuildKey)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleID]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if process.terminationStatus == 0 {
                logger.notice("cleared Accessibility entry before first prompt of build \(build): \(output)")
            } else {
                logger.error("tccutil reset failed for build \(build) exit=\(process.terminationStatus): \(output)")
            }
        } catch {
            logger.error("tccutil could not be launched for build \(build): \(error)")
        }
    }
}
