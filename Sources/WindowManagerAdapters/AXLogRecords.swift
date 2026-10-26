import ApplicationServices

enum AttributeReadFailure: Error, Equatable {
    case readFailed(attribute: String, error: AXError)
    case missingValue(attribute: String)
    case decodeFailed(attribute: String)

    var description: String {
        switch self {
        case let .readFailed(attribute, error):
            return "attribute=\(attribute) readAXError=\(error.rawValue)"
        case let .missingValue(attribute):
            return "attribute=\(attribute) missingValue"
        case let .decodeFailed(attribute):
            return "attribute=\(attribute) decodeFailed"
        }
    }
}

struct FocusedWindowLogRecord {
    struct Wake: Equatable {
        let manualAXWrite: AXError
        let euiWrite: AXError
        let retryAXError: AXError
    }

    enum Outcome {
        case ok
        case readFailed(callerTrusted: Bool)
        case missingFocusedWindow(callerTrusted: Bool)
        case windowUnreadable(AttributeReadFailure, callerTrusted: Bool)
    }

    let pid: pid_t
    let bundle: String
    let name: String
    let firstAXError: AXError
    let wake: Wake?
    let outcome: Outcome

    var isFailure: Bool {
        if case .ok = outcome { return false }
        return true
    }

    var message: String {
        var fields = "pid=\(pid) bundle=\(bundle) name=\(name) firstAXError=\(firstAXError.rawValue)"
        if let wake {
            fields += " wakeAttempted=true manualAXWrite=\(wake.manualAXWrite.rawValue) euiWrite=\(wake.euiWrite.rawValue) retryAXError=\(wake.retryAXError.rawValue)"
        } else {
            fields += " wakeAttempted=false"
        }
        switch outcome {
        case .ok:
            return "getFocusedWindow ok \(fields)"
        case let .readFailed(callerTrusted):
            return "getFocusedWindow failed \(fields) callerTrusted=\(callerTrusted)"
        case let .missingFocusedWindow(callerTrusted):
            return "getFocusedWindow failed \(fields) missingFocusedWindow callerTrusted=\(callerTrusted)"
        case let .windowUnreadable(failure, callerTrusted):
            return "getFocusedWindow failed \(fields) windowUnreadable \(failure.description) callerTrusted=\(callerTrusted)"
        }
    }
}

struct WindowFrameLogRecord {
    struct Flip {
        let offAXError: AXError
        let restoreAXError: AXError
    }

    struct EUI {
        let readAXError: AXError
        let flip: Flip?
    }

    struct Attempt {
        let position: AXError
        let size: AXError
        let positionAgain: AXError
    }

    let pid: pid_t
    let pidAXError: AXError
    let eui: EUI?
    let wasZoomed: Bool
    let attempts: [Attempt]
    let ok: Bool
    let elapsedMs: Double

    var isFailure: Bool {
        !ok || (eui?.flip.map { $0.restoreAXError != .success } ?? false)
    }

    var message: String {
        var fields = "setWindowFrame pid=\(pid) pidAXError=\(pidAXError.rawValue)"
        if let eui {
            fields += " euiReadAXError=\(eui.readAXError.rawValue)"
            if eui.readAXError == .success {
                fields += " wasEUI=\(eui.flip != nil)"
            }
            if let flip = eui.flip {
                fields += " euiOffAXError=\(flip.offAXError.rawValue) euiRestoreAXError=\(flip.restoreAXError.rawValue)"
            }
        } else {
            fields += " eui=notAttempted"
        }
        let writes = attempts
            .map { "\($0.position.rawValue)/\($0.size.rawValue)/\($0.positionAgain.rawValue)" }
            .joined(separator: ";")
        fields += " wasZoomed=\(wasZoomed) attempts=\(attempts.count) writes=\(writes)"
        fields += " result=\(ok ? "ok" : "failed") elapsedMs=\(String(format: "%.1f", elapsedMs))"
        return fields
    }
}
