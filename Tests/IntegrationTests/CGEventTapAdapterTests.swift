import Testing
import Foundation
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("CGEventTapAdapter")
struct CGEventTapAdapterTests {

    @Test(.enabled(if: isAccessibilityTrusted))
    func startAndStopDoNotCrash() {
        let adapter = CGEventTapAdapter()
        adapter.start { _, _ in false }
        adapter.stop()
    }

    @Test func stopWithoutStartDoesNotCrash() {
        let adapter = CGEventTapAdapter()
        adapter.stop()
    }

    @Test func ensureEnabledWithoutStartDoesNotCrash() {
        let adapter = CGEventTapAdapter()
        adapter.ensureEnabled()
    }
}
