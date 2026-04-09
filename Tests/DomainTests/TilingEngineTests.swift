import Testing
import Foundation
@testable import WindowManagerDomain

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
}

private func expectFrame(_ actual: CGRect, _ expected: CGRect, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(actual.origin.x == expected.origin.x, "x: \(actual.origin.x) != \(expected.origin.x)", sourceLocation: sourceLocation)
    #expect(actual.origin.y == expected.origin.y, "y: \(actual.origin.y) != \(expected.origin.y)", sourceLocation: sourceLocation)
    #expect(actual.size.width == expected.size.width, "width: \(actual.size.width) != \(expected.size.width)", sourceLocation: sourceLocation)
    #expect(actual.size.height == expected.size.height, "height: \(actual.size.height) != \(expected.size.height)", sourceLocation: sourceLocation)
}

@Suite("TilingEngine")
struct TilingEngineTests {

    let engine = TilingEngine()

    let standardScreen = ScreenInfo(
        id: 0,
        frame: rect(0, 0, 1920, 1080),
        visibleFrame: rect(0, 0, 1920, 1080),
        isPrimary: true
    )

    let dummyWindow = WindowInfo(
        ref: WindowRef(id: 1),
        position: CGPoint(x: 100, y: 100),
        size: CGSize(width: 800, height: 600),
        screenID: 0,
        isFullscreen: false
    )

    // MARK: - All actions on 1920x1080, padding=0

    @Test func leftHalfNoPadding() {
        let frame = engine.computeFrame(action: .leftHalf, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 0, 960, 1080))
    }

    @Test func rightHalfNoPadding() {
        let frame = engine.computeFrame(action: .rightHalf, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(960, 0, 960, 1080))
    }

    @Test func topHalfNoPadding() {
        let frame = engine.computeFrame(action: .topHalf, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 0, 1920, 540))
    }

    @Test func bottomHalfNoPadding() {
        let frame = engine.computeFrame(action: .bottomHalf, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 540, 1920, 540))
    }

    @Test func topLeftNoPadding() {
        let frame = engine.computeFrame(action: .topLeft, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 0, 960, 540))
    }

    @Test func topRightNoPadding() {
        let frame = engine.computeFrame(action: .topRight, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(960, 0, 960, 540))
    }

    @Test func bottomLeftNoPadding() {
        let frame = engine.computeFrame(action: .bottomLeft, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 540, 960, 540))
    }

    @Test func bottomRightNoPadding() {
        let frame = engine.computeFrame(action: .bottomRight, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(960, 540, 960, 540))
    }

    @Test func maximizeNoPadding() {
        let frame = engine.computeFrame(action: .maximize, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 0, 1920, 1080))
    }

    @Test func centerNoPadding() {
        let frame = engine.computeFrame(action: .center, screen: standardScreen, currentWindow: dummyWindow)
        expectFrame(frame, rect(560, 240, 800, 600))
    }

    // MARK: - Padding > 0

    @Test func leftHalfWithPadding() {
        let frame = engine.computeFrame(action: .leftHalf, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(10, 10, 945, 1060))
    }

    @Test func rightHalfWithPadding() {
        let frame = engine.computeFrame(action: .rightHalf, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(965, 10, 945, 1060))
    }

    @Test func topHalfWithPadding() {
        let frame = engine.computeFrame(action: .topHalf, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(10, 10, 1900, 525))
    }

    @Test func bottomHalfWithPadding() {
        let frame = engine.computeFrame(action: .bottomHalf, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(10, 545, 1900, 525))
    }

    @Test func maximizeWithPadding() {
        let frame = engine.computeFrame(action: .maximize, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(10, 10, 1900, 1060))
    }

    @Test func topLeftWithPadding() {
        let frame = engine.computeFrame(action: .topLeft, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(10, 10, 945, 525))
    }

    @Test func bottomRightWithPadding() {
        let frame = engine.computeFrame(action: .bottomRight, screen: standardScreen, currentWindow: dummyWindow, padding: 10)
        expectFrame(frame, rect(965, 545, 945, 525))
    }

    // MARK: - Menu bar offset

    @Test func leftHalfWithMenuBar() {
        let screen = ScreenInfo(
            id: 0,
            frame: rect(0, 0, 1920, 1080),
            visibleFrame: rect(0, 25, 1920, 1055),
            isPrimary: true
        )
        let frame = engine.computeFrame(action: .leftHalf, screen: screen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 25, 960, 1055))
    }

    @Test func maximizeWithMenuBar() {
        let screen = ScreenInfo(
            id: 0,
            frame: rect(0, 0, 1920, 1080),
            visibleFrame: rect(0, 25, 1920, 1055),
            isPrimary: true
        )
        let frame = engine.computeFrame(action: .maximize, screen: screen, currentWindow: dummyWindow)
        expectFrame(frame, rect(0, 25, 1920, 1055))
    }

    @Test func topHalfWithMenuBar() {
        let screen = ScreenInfo(
            id: 0,
            frame: rect(0, 0, 1920, 1080),
            visibleFrame: rect(0, 25, 1920, 1055),
            isPrimary: true
        )
        let frame = engine.computeFrame(action: .topHalf, screen: screen, currentWindow: dummyWindow)
        #expect(frame.origin.y == 25)
        #expect(frame.size.height == 1055.0 / 2)
    }

    // MARK: - Secondary display offset

    @Test func leftHalfSecondaryDisplay() {
        let screen = ScreenInfo(
            id: 1,
            frame: rect(1920, 0, 1920, 1080),
            visibleFrame: rect(1920, 0, 1920, 1080),
            isPrimary: false
        )
        let frame = engine.computeFrame(action: .leftHalf, screen: screen, currentWindow: dummyWindow)
        expectFrame(frame, rect(1920, 0, 960, 1080))
    }

    @Test func rightHalfSecondaryDisplay() {
        let screen = ScreenInfo(
            id: 1,
            frame: rect(1920, 0, 1920, 1080),
            visibleFrame: rect(1920, 0, 1920, 1080),
            isPrimary: false
        )
        let frame = engine.computeFrame(action: .rightHalf, screen: screen, currentWindow: dummyWindow)
        expectFrame(frame, rect(2880, 0, 960, 1080))
    }

    @Test func maximizeSecondaryDisplay() {
        let screen = ScreenInfo(
            id: 1,
            frame: rect(1920, 0, 2560, 1440),
            visibleFrame: rect(1920, 25, 2560, 1415),
            isPrimary: false
        )
        let frame = engine.computeFrame(action: .maximize, screen: screen, currentWindow: dummyWindow)
        expectFrame(frame, rect(1920, 25, 2560, 1415))
    }

    // MARK: - Center preserves window size

    @Test func centerPreservesSize() {
        let smallWindow = WindowInfo(
            ref: WindowRef(id: 2),
            position: CGPoint(x: 0, y: 0),
            size: CGSize(width: 400, height: 300),
            screenID: 0,
            isFullscreen: false
        )
        let frame = engine.computeFrame(action: .center, screen: standardScreen, currentWindow: smallWindow)
        #expect(frame.size.width == 400)
        #expect(frame.size.height == 300)
        #expect(frame.origin.x == 760)
        #expect(frame.origin.y == 390)
    }

    @Test func centerOnSecondaryDisplay() {
        let screen = ScreenInfo(
            id: 1,
            frame: rect(1920, 0, 1920, 1080),
            visibleFrame: rect(1920, 0, 1920, 1080),
            isPrimary: false
        )
        let frame = engine.computeFrame(action: .center, screen: screen, currentWindow: dummyWindow)
        #expect(frame.size.width == 800)
        #expect(frame.size.height == 600)
        #expect(frame.origin.x == 2480)
        #expect(frame.origin.y == 240)
    }
}
