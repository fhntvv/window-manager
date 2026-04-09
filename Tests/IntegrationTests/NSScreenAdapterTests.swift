import Testing
import Foundation
@testable import WindowManagerAdapters
@testable import WindowManagerDomain

@Suite("NSScreenAdapter")
struct NSScreenAdapterTests {

    let adapter = NSScreenAdapter()

    @Test func allScreensNonEmpty() throws {
        let screens = adapter.allScreens()
        #expect(!screens.isEmpty)
    }

    @Test func primaryScreenIsPrimary() throws {
        let screens = adapter.allScreens()
        let primary = screens.first { $0.isPrimary }
        #expect(primary != nil)
    }

    @Test func visibleFrameWithinFrame() throws {
        let screens = adapter.allScreens()
        for screen in screens {
            #expect(screen.visibleFrame.minX >= screen.frame.minX)
            #expect(screen.visibleFrame.minY >= screen.frame.minY)
            #expect(screen.visibleFrame.maxX <= screen.frame.maxX)
            #expect(screen.visibleFrame.maxY <= screen.frame.maxY)
        }
    }

    @Test func primaryScreenHeightPositive() throws {
        let height = adapter.primaryScreenHeight()
        #expect(height > 0)
    }

    @Test func screenContainingOrigin() throws {
        let screens = adapter.allScreens()
        guard let primary = screens.first(where: { $0.isPrimary }) else { return }
        let midPoint = CGPoint(
            x: primary.frame.midX,
            y: primary.frame.midY
        )
        let found = adapter.screenContaining(point: midPoint)
        #expect(found != nil)
        #expect(found?.id == primary.id)
    }
}
