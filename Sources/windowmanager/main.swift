import Foundation
import WindowManagerDomain

DebugLogger.isDebugMode = CommandLine.arguments.contains("--debug")

do {
    try MainActor.assumeIsolated {
        let root = try AppCompositionRoot()
        root.run()
    }
} catch {
    let logger = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")
    logger.fault("Failed to start: \(error)")
    exit(1)
}
