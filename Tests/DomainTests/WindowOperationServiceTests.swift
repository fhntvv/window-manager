import Testing
import Foundation
@testable import WindowManagerDomain

private func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
    CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: w, height: h))
}

private func screen(_ id: Int, x: CGFloat = 0, y: CGFloat = 0, w: CGFloat = 1920, h: CGFloat = 1080) -> ScreenInfo {
    ScreenInfo(id: id, frame: rect(x, y, w, h), visibleFrame: rect(x, y, w, h), isPrimary: id == 0)
}

private func window(_ id: Int = 1, x: CGFloat = 100, y: CGFloat = 100, w: CGFloat = 800, h: CGFloat = 600, screenID: Int = 0, fullscreen: Bool = false) -> WindowInfo {
    WindowInfo(ref: WindowRef(id: id), position: CGPoint(x: x, y: y),
               size: CGSize(width: w, height: h), screenID: screenID, isFullscreen: fullscreen)
}

@Suite("WindowOperationService")
struct WindowOperationServiceTests {

    @Test func leftHalfSetsCorrectFrame() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = window()
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.leftHalf)

        #expect(fakeAccess.setFrameCalls.count == 1)
        let call = fakeAccess.setFrameCalls[0]
        #expect(call.size.width == 960)
        #expect(call.size.height == 1080)
        #expect(call.position.x == 0)
        #expect(call.position.y == 0)
    }

    @Test func noFocusedWindowDoesNothing() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = nil
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.leftHalf)

        #expect(fakeAccess.setFrameCalls.isEmpty)
    }

    @Test func fullscreenWindowIsSkipped() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = window(fullscreen: true)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.maximize)

        #expect(fakeAccess.setFrameCalls.isEmpty)
    }

    @Test func nextDisplayTripleWrite() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0), screen(1, x: 1920)]
        fakeAccess.focusedWindow = window(screenID: 0)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.nextDisplay)

        #expect(fakeAccess.setFrameCalls.count == 3)
        let finalCall = fakeAccess.setFrameCalls[2]
        #expect(finalCall.position.x == 1920)
        #expect(finalCall.size.width == 1920)
        #expect(finalCall.size.height == 1080)
    }

    @Test func prevDisplayWrapsToLastScreen() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0), screen(1, x: 1920)]
        fakeAccess.focusedWindow = window(screenID: 0)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.prevDisplay)

        #expect(fakeAccess.setFrameCalls.count == 3)
        let finalCall = fakeAccess.setFrameCalls[2]
        #expect(finalCall.position.x == 1920)
    }

    @Test func nextDisplaySingleScreenDoesNothing() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = window()
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.nextDisplay)

        #expect(fakeAccess.setFrameCalls.isEmpty)
    }

    @Test func rightHalfSetsCorrectFrame() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = window()
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.rightHalf)

        #expect(fakeAccess.setFrameCalls.count == 1)
        let call = fakeAccess.setFrameCalls[0]
        #expect(call.position.x == 960)
        #expect(call.size.width == 960)
    }

    @Test func emptyScreensDoesNothing() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = []
        fakeAccess.focusedWindow = window()
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.leftHalf)

        #expect(fakeAccess.setFrameCalls.isEmpty)
    }

    @Test func screenFallbackToContainingPoint() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0), screen(1, x: 1920)]
        fakeAccess.focusedWindow = window(x: 2000, y: 100, screenID: 99)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.maximize)

        #expect(fakeAccess.setFrameCalls.count == 1)
        let call = fakeAccess.setFrameCalls[0]
        #expect(call.position.x == 1920)
        #expect(call.size.width == 1920)
    }

    @Test func screenFallbackToFirstScreen() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0)]
        fakeAccess.focusedWindow = window(x: 9999, y: 9999, screenID: 99)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.maximize)

        #expect(fakeAccess.setFrameCalls.count == 1)
        let call = fakeAccess.setFrameCalls[0]
        #expect(call.position.x == 0)
        #expect(call.size.width == 1920)
    }

    @Test func displayMoveUnknownScreenDoesNothing() {
        let fakeAccess = FakeWindowAccess()
        let fakeScreens = FakeScreenInfo()
        fakeScreens.screens = [screen(0), screen(1, x: 1920)]
        fakeAccess.focusedWindow = window(screenID: 99)
        let service = WindowOperationService(windowAccess: fakeAccess, screenInfo: fakeScreens)

        service.execute(.nextDisplay)

        #expect(fakeAccess.setFrameCalls.isEmpty)
    }
}
