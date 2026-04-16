import Foundation
import os

do {
    try MainActor.assumeIsolated {
        let root = try AppCompositionRoot()
        root.run()
    }
} catch {
    let logger = Logger(subsystem: "com.windowmanager", category: "Lifecycle")
    logger.fault("Failed to start: \(error, privacy: .public)")
    exit(1)
}
