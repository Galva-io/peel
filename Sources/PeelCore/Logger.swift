import Foundation
import OSLog

/// Centralized logger so subsystems share one tag.
public enum PeelLog {
    public static let subsystem = "io.galva.peel"
    public static let auth = Logger(subsystem: subsystem, category: "auth")
    public static let api = Logger(subsystem: subsystem, category: "api")
    public static let webhook = Logger(subsystem: subsystem, category: "webhook")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
    public static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")
}
