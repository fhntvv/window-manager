import AppKit
import CryptoKit
import Foundation
import Security
import WindowManagerDomain

enum SignatureSelfCheckResult {
    case ok
    case adhocOrUnsigned
    case unexpectedLeaf(actualHash: String)
    case unavailable(reason: String)
}

@MainActor
enum SignatureSelfCheck {
    static func evaluate() -> SignatureSelfCheckResult {
        var codeRef: SecCode?
        let getSelfStatus = SecCodeCopySelf(SecCSFlags(rawValue: 0), &codeRef)
        guard getSelfStatus == errSecSuccess, let code = codeRef else {
            return .unavailable(reason: "SecCodeCopySelf failed (status=\(getSelfStatus))")
        }

        var staticCodeRef: SecStaticCode?
        let staticStatus = SecCodeCopyStaticCode(code, SecCSFlags(rawValue: 0), &staticCodeRef)
        guard staticStatus == errSecSuccess, let staticCode = staticCodeRef else {
            return .unavailable(reason: "SecCodeCopyStaticCode failed (status=\(staticStatus))")
        }

        var infoRef: CFDictionary?
        let infoStatus = SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)),
            &infoRef
        )
        guard infoStatus == errSecSuccess, let info = infoRef as? [String: Any] else {
            return .unavailable(reason: "SecCodeCopySigningInformation failed (status=\(infoStatus))")
        }

        guard
            let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
            !certs.isEmpty
        else {
            return .adhocOrUnsigned
        }

        let leafData = SecCertificateCopyData(certs[0]) as Data
        let leafHash = Insecure.SHA1.hash(data: leafData)
        let leafHex = leafHash.map { String(format: "%02x", $0) }.joined()

        if leafHex.caseInsensitiveCompare(SigningExpectation.expectedLeafCertSHA1) == .orderedSame {
            return .ok
        }
        return .unexpectedLeaf(actualHash: leafHex)
    }

    static func runAndWarnIfMisconfigured(logger: DebugLogger) {
        let result = evaluate()
        switch result {
        case .ok:
            return
        case .unavailable(let reason):
            logger.warning("signature self-check unavailable: \(reason)")
        case .adhocOrUnsigned:
            logger.warning("this bundle is adhoc/unsigned — macOS TCC grants will silently break on the next signed upgrade. Reinstall via `make install`.")
            presentAlertOnceIfInstalled(
                identifier: "adhoc",
                title: "WindowManager is running an unsigned build",
                body: """
                This bundle is not signed with the project's release identity. macOS Accessibility \
                (and other TCC permissions) cannot keep grants pinned across upgrades for an unsigned \
                binary — the grant will silently break the next time a signed build replaces this one, \
                and hotkeys will stop moving windows with no visible error.

                To install a signed build, quit the app and run `make install` from the project directory.
                """
            )
        case .unexpectedLeaf(let actualHash):
            logger.warning("this bundle is signed with leaf cert \(actualHash); expected \(SigningExpectation.expectedLeafCertSHA1). TCC grants from previous builds will not match.")
            presentAlertOnceIfInstalled(
                identifier: "unexpected-\(actualHash)",
                title: "WindowManager signed with unexpected identity",
                body: """
                This bundle's signing certificate (leaf hash \(actualHash)) does not match the \
                expected identity baked into this build (\(SigningExpectation.expectedLeafCertSHA1)). \
                Any TCC grants from previous builds will not transfer to this binary; you may need to \
                re-grant Accessibility in System Settings.
                """
            )
        }
    }

    private static func presentAlertOnceIfInstalled(identifier: String, title: String, body: String) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }

        let defaults = UserDefaults.standard
        let key = "SignatureSelfCheck.warned.\(identifier)"
        if defaults.bool(forKey: key) { return }
        defaults.set(true, forKey: key)

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
