public enum AccessibilityResetPolicy {
    public static func shouldReset(isTrusted: Bool, build: String, lastResetBuild: String?) -> Bool {
        !isTrusted && lastResetBuild != build
    }
}
