import WindowManagerDomain

enum Log {
    static let eventTap = DebugLogger(subsystem: "com.windowmanager", category: "EventTap")
    static let windowOps = DebugLogger(subsystem: "com.windowmanager", category: "WindowOps")
    static let config = DebugLogger(subsystem: "com.windowmanager", category: "Config")
    static let lifecycle = DebugLogger(subsystem: "com.windowmanager", category: "Lifecycle")
}
