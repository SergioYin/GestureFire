import os

/// Centralized os.Logger instances for structured logging.
extension Logger {
    private static let subsystem = "com.gesturefire"

    static let engine = Logger(subsystem: subsystem, category: "engine")
    static let recognition = Logger(subsystem: subsystem, category: "recognition")
    static let config = Logger(subsystem: subsystem, category: "config")
    static let diagnostic = Logger(subsystem: subsystem, category: "diagnostic")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
