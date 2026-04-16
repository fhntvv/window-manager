import os

enum Log {
    static let eventTap = Logger(subsystem: "com.windowmanager", category: "EventTap")
    static let windowOps = Logger(subsystem: "com.windowmanager", category: "WindowOps")
    static let config = Logger(subsystem: "com.windowmanager", category: "Config")
    static let lifecycle = Logger(subsystem: "com.windowmanager", category: "Lifecycle")
}
