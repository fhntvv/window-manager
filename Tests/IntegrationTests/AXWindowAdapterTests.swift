import Testing
import Foundation
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("AXWindowAdapter")
struct AXWindowAdapterTests {

    let adapter = AXWindowAdapter()

    @Test(.enabled(if: isAccessibilityTrusted))
    func getFocusedWindowReturnsValidDimensions() {
        guard let window = adapter.getFocusedWindow() else {
            return
        }
        #expect(window.size.width > 0)
        #expect(window.size.height > 0)
    }

    @Test(.enabled(if: isAccessibilityTrusted))
    func getWindowInfoForFocusedWindow() {
        guard let window = adapter.getFocusedWindow() else {
            return
        }
        let info = adapter.getWindowInfo(window.ref)
        #expect(info != nil)
        #expect(info?.size.width == window.size.width)
        #expect(info?.size.height == window.size.height)
    }

    @Test(.enabled(if: isAccessibilityTrusted))
    func getWindowInfoForUnknownRefReturnsNil() {
        let unknownRef = WindowRef(id: 999_999)
        let info = adapter.getWindowInfo(unknownRef)
        #expect(info == nil)
    }
}
