import Testing
import Foundation
@testable import WindowManagerDomain

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
}

@Suite("FrameRenderer")
struct FrameRendererTests {

    let renderer = FrameRenderer()

    let standardScreen = ScreenInfo(
        id: 0,
        frame: rect(0, 0, 1920, 1080),
        visibleFrame: rect(0, 0, 1920, 1080),
        isPrimary: true
    )

    @Test func leftHalfBeforeAfter() {
        let before = (label: "before", frame: rect(100, 100, 800, 600), screenID: 0)
        let after = (label: "after", frame: rect(0, 0, 960, 1080), screenID: 0)

        let output = renderer.render(screens: [standardScreen], windows: [before, after])

        #expect(output.contains("before"))
        #expect(output.contains("after"))
    }

    @Test func dualDisplayWithWindowMigration() {
        let screen0 = ScreenInfo(
            id: 0,
            frame: rect(0, 0, 1920, 1080),
            visibleFrame: rect(0, 0, 1920, 1080),
            isPrimary: true
        )
        let screen1 = ScreenInfo(
            id: 1,
            frame: rect(1920, 0, 1920, 1080),
            visibleFrame: rect(1920, 0, 1920, 1080),
            isPrimary: false
        )

        let win = (label: "migrated", frame: rect(1920, 0, 1920, 1080), screenID: 1)
        let output = renderer.render(screens: [screen0, screen1], windows: [win])

        #expect(output.contains("migrated"))
        let lines = output.split(separator: "\n")
        let maxWidth = lines.map { $0.count }.max() ?? 0
        #expect(maxWidth > 96)
    }

    @Test func fourQuarters() {
        let engine = TilingEngine()
        let dummyWindow = WindowInfo(
            ref: WindowRef(id: 1), position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 800, height: 600), screenID: 0, isFullscreen: false
        )

        let tl = engine.computeFrame(action: .topLeft, screen: standardScreen, currentWindow: dummyWindow)
        let tr = engine.computeFrame(action: .topRight, screen: standardScreen, currentWindow: dummyWindow)
        let bl = engine.computeFrame(action: .bottomLeft, screen: standardScreen, currentWindow: dummyWindow)
        let br = engine.computeFrame(action: .bottomRight, screen: standardScreen, currentWindow: dummyWindow)

        let windows: [(label: String, frame: CGRect, screenID: Int)] = [
            (label: "TL", frame: tl, screenID: 0),
            (label: "TR", frame: tr, screenID: 0),
            (label: "BL", frame: bl, screenID: 0),
            (label: "BR", frame: br, screenID: 0),
        ]

        let output = renderer.render(screens: [standardScreen], windows: windows)

        #expect(output.contains("TL"))
        #expect(output.contains("TR"))
        #expect(output.contains("BL"))
        #expect(output.contains("BR"))
    }

    @Test func emptyScreensReturnsEmpty() {
        let output = renderer.render(screens: [], windows: [])
        #expect(output == "")
    }
}
