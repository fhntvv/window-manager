import Foundation

do {
    try MainActor.assumeIsolated {
        let root = try AppCompositionRoot()
        root.run()
    }
} catch {
    fputs("Failed to start: \(error)\n", stderr)
    exit(1)
}
