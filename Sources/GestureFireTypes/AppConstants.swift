import Foundation

public enum AppConstants {
    public static let bundleIdentifier = "com.gesturefire.app"
    public static let configDirectoryName = "gesturefire"
    public static let configFileName = "config.json"
    public static let logDirectoryName = "logs"
    public static let sampleDirectoryName = "samples"

    /// ~/.config/gesturefire/
    public static var configDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent(configDirectoryName)
    }

    /// ~/.config/gesturefire/config.json
    public static var configFile: URL {
        configDirectory.appendingPathComponent(configFileName)
    }

    /// ~/.config/gesturefire/logs/
    public static var logDirectory: URL {
        configDirectory.appendingPathComponent(logDirectoryName)
    }

    /// ~/.config/gesturefire/samples/
    public static var sampleDirectory: URL {
        configDirectory.appendingPathComponent(sampleDirectoryName)
    }
}
