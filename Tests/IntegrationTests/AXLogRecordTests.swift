import Testing
import ApplicationServices
@testable import WindowManagerAdapters

@Suite("AX log records")
struct AXLogRecordTests {

    @Test func focusedWindowFailureReportsTargetAndEveryWakeStep() {
        let record = FocusedWindowLogRecord(
            pid: 70750,
            bundle: "com.tinyspeck.slackmacgap",
            name: "Slack",
            firstAXError: .noValue,
            wake: .init(manualAXWrite: .attributeUnsupported, euiWrite: .success, retryAXError: .apiDisabled),
            outcome: .readFailed(callerTrusted: true)
        )

        let message = record.message
        #expect(message.hasPrefix("getFocusedWindow failed "))
        #expect(message.contains("pid=70750"))
        #expect(message.contains("bundle=com.tinyspeck.slackmacgap"))
        #expect(message.contains("firstAXError=-25212"))
        #expect(message.contains("wakeAttempted=true"))
        #expect(message.contains("manualAXWrite=-25205"))
        #expect(message.contains("euiWrite=0"))
        #expect(message.contains("retryAXError=-25211"))
        #expect(message.contains("callerTrusted=true"))
    }

    @Test func focusedWindowOmitsWakeStepsThatNeverRan() {
        let record = FocusedWindowLogRecord(
            pid: 1435,
            bundle: "com.umputun.agterm",
            name: "Agterm",
            firstAXError: .success,
            wake: nil,
            outcome: .ok
        )

        let message = record.message
        #expect(message.hasPrefix("getFocusedWindow ok "))
        #expect(message.contains("wakeAttempted=false"))
        #expect(!message.contains("manualAXWrite"))
        #expect(!message.contains("euiWrite"))
        #expect(!message.contains("retryAXError"))
    }

    @Test(arguments: [
        (FocusedWindowLogRecord.Wake?.none, FocusedWindowLogRecord.Outcome.ok, false),
        (.init(manualAXWrite: .success, euiWrite: .success, retryAXError: .success), .ok, false),
        (.init(manualAXWrite: .apiDisabled, euiWrite: .apiDisabled, retryAXError: .apiDisabled), .readFailed(callerTrusted: true), true),
        (nil, .missingFocusedWindow(callerTrusted: true), true),
        (nil, .windowUnreadable(.decodeFailed(attribute: "AXSize"), callerTrusted: true), true),
    ])
    func focusedWindowIsFailureOnlyWhenNoUsableWindow(
        wake: FocusedWindowLogRecord.Wake?,
        outcome: FocusedWindowLogRecord.Outcome,
        isFailure: Bool
    ) {
        let record = FocusedWindowLogRecord(
            pid: 587,
            bundle: "com.tinyspeck.slackmacgap",
            name: "Slack",
            firstAXError: wake == nil ? .success : .cannotComplete,
            wake: wake,
            outcome: outcome
        )

        #expect(record.isFailure == isFailure)
    }

    @Test func focusedWindowReportsMissingWindowDistinctlyFromReadError() {
        let record = FocusedWindowLogRecord(
            pid: 70750,
            bundle: "com.tinyspeck.slackmacgap",
            name: "Slack",
            firstAXError: .noValue,
            wake: .init(manualAXWrite: .success, euiWrite: .success, retryAXError: .success),
            outcome: .missingFocusedWindow(callerTrusted: false)
        )

        let message = record.message
        #expect(message.hasPrefix("getFocusedWindow failed "))
        #expect(message.contains("retryAXError=0"))
        #expect(message.contains("missingFocusedWindow"))
        #expect(message.contains("callerTrusted=false"))
    }

    @Test(arguments: [
        (AttributeReadFailure.readFailed(attribute: "AXPosition", error: .cannotComplete), ["attribute=AXPosition", "readAXError=-25204"]),
        (.missingValue(attribute: "AXSize"), ["attribute=AXSize", "missingValue"]),
        (.decodeFailed(attribute: "AXSize"), ["attribute=AXSize", "decodeFailed"]),
    ])
    func focusedWindowUnreadableNamesTheFailingAttribute(failure: AttributeReadFailure, expected: [String]) {
        let record = FocusedWindowLogRecord(
            pid: 99956,
            bundle: "com.apple.Notes",
            name: "Notes",
            firstAXError: .success,
            wake: nil,
            outcome: .windowUnreadable(failure, callerTrusted: true)
        )

        for token in expected {
            #expect(record.message.contains(token))
        }
        #expect(record.message.hasPrefix("getFocusedWindow failed "))
        #expect(record.message.contains("pid=99956"))
        #expect(record.message.contains("callerTrusted=true"))
    }

    @Test func windowFrameListsEveryAttemptInOrder() {
        let record = WindowFrameLogRecord(
            pid: 587,
            pidAXError: .success,
            eui: .init(readAXError: .success, flip: nil),
            wasZoomed: false,
            attempts: [
                .init(position: .apiDisabled, size: .cannotComplete, positionAgain: .noValue),
                .init(position: .success, size: .success, positionAgain: .success),
            ],
            ok: true,
            elapsedMs: 56.25
        )

        #expect(record.message.contains("attempts=2"))
        #expect(record.message.contains("writes=-25211/-25204/-25212;0/0/0"))
        #expect(record.message.contains("result=ok"))
    }

    @Test func windowFrameReportsFailedWrites() {
        let failed = WindowFrameLogRecord.Attempt(position: .apiDisabled, size: .apiDisabled, positionAgain: .apiDisabled)
        let record = WindowFrameLogRecord(
            pid: 70750,
            pidAXError: .success,
            eui: .init(readAXError: .success, flip: nil),
            wasZoomed: false,
            attempts: [failed, failed, failed],
            ok: false,
            elapsedMs: 120
        )

        #expect(record.message.contains("attempts=3"))
        #expect(record.message.contains("result=failed"))
    }

    @Test func windowFrameOmitsFlipStepsWhenEUIWasOff() {
        let record = WindowFrameLogRecord(
            pid: 99956,
            pidAXError: .success,
            eui: .init(readAXError: .success, flip: nil),
            wasZoomed: false,
            attempts: [.init(position: .success, size: .success, positionAgain: .success)],
            ok: true,
            elapsedMs: 4.5
        )

        let message = record.message
        #expect(message.contains("euiReadAXError=0"))
        #expect(message.contains("wasEUI=false"))
        #expect(!message.contains("euiOffAXError"))
        #expect(!message.contains("euiRestoreAXError"))
    }

    @Test func windowFrameOmitsWasEUIWhenEUIReadFailed() {
        let record = WindowFrameLogRecord(
            pid: 70750,
            pidAXError: .success,
            eui: .init(readAXError: .apiDisabled, flip: nil),
            wasZoomed: false,
            attempts: [.init(position: .success, size: .success, positionAgain: .success)],
            ok: true,
            elapsedMs: 2
        )

        let message = record.message
        #expect(message.contains("euiReadAXError=-25211"))
        #expect(!message.contains("wasEUI"))
    }

    @Test func windowFrameReportsOffAndRestoreSeparately() {
        let record = WindowFrameLogRecord(
            pid: 1435,
            pidAXError: .success,
            eui: .init(readAXError: .success, flip: .init(offAXError: .apiDisabled, restoreAXError: .cannotComplete)),
            wasZoomed: false,
            attempts: [.init(position: .success, size: .success, positionAgain: .success)],
            ok: true,
            elapsedMs: 3.7
        )

        let message = record.message
        #expect(message.contains("wasEUI=true"))
        #expect(message.contains("euiOffAXError=-25211"))
        #expect(message.contains("euiRestoreAXError=-25204"))
    }

    @Test func windowFrameWithoutAppElementMarksEUINotAttempted() {
        let record = WindowFrameLogRecord(
            pid: 0,
            pidAXError: .invalidUIElement,
            eui: nil,
            wasZoomed: false,
            attempts: [.init(position: .invalidUIElement, size: .invalidUIElement, positionAgain: .invalidUIElement)],
            ok: false,
            elapsedMs: 1
        )

        let message = record.message
        #expect(message.contains("pidAXError=-25202"))
        #expect(message.contains("eui=notAttempted"))
        #expect(!message.contains("wasEUI"))
    }

    @Test(arguments: [
        (true, WindowFrameLogRecord.Flip?.none, false),
        (true, .init(offAXError: .success, restoreAXError: .success), false),
        (true, .init(offAXError: .success, restoreAXError: .cannotComplete), true),
        (false, .init(offAXError: .success, restoreAXError: .success), true),
        (false, nil, true),
    ])
    func windowFrameIsFailureWhenWritesOrRestoreFail(ok: Bool, flip: WindowFrameLogRecord.Flip?, isFailure: Bool) {
        let write: AXError = ok ? .success : .cannotComplete
        let record = WindowFrameLogRecord(
            pid: 1435,
            pidAXError: .success,
            eui: .init(readAXError: .success, flip: flip),
            wasZoomed: false,
            attempts: [.init(position: write, size: write, positionAgain: write)],
            ok: ok,
            elapsedMs: 5
        )

        #expect(record.isFailure == isFailure)
    }
}
