import Testing
@testable import WindowManagerDomain

@Suite("Accessibility reset policy")
struct AccessibilityResetPolicyTests {

    @Test(arguments: [
        (true, "0.4.3", String?.none, false),
        (true, "0.4.4", "0.4.3", false),
        (false, "0.4.3", nil, true),
        (false, "0.4.4", "0.4.3", true),
        (false, "0.4.3", "0.4.3", false),
    ])
    func resetsOnlyWhenUntrustedAndNotYetDoneForThisBuild(
        isTrusted: Bool,
        build: String,
        lastResetBuild: String?,
        expected: Bool
    ) {
        let decision = AccessibilityResetPolicy.shouldReset(
            isTrusted: isTrusted,
            build: build,
            lastResetBuild: lastResetBuild
        )

        #expect(decision == expected)
    }
}
