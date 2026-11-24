import Foundation

public enum SharedLocation {
    public static let folderName = "SpotifyNow"

    public static func storeDirectory(in container: URL) -> URL {
        container.appendingPathComponent(folderName, isDirectory: true)
    }

    public static func widgetApplicationSupport(home: URL, widgetBundleID: String) -> URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(widgetBundleID, isDirectory: true)
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
    }

    /// True once macOS has created the extension container. Creating that folder
    /// ourselves can make the widget fail to launch.
    public static func widgetContainerIsReady(home: URL, widgetBundleID: String, fileExists: (URL) -> Bool) -> Bool {
        let root = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Containers", isDirectory: true)
            .appendingPathComponent(widgetBundleID, isDirectory: true)
        let metadata = root.appendingPathComponent(".com.apple.containermanagerd.metadata.plist")
        let dataLibrary = root
            .appendingPathComponent("Data", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
        return fileExists(metadata) || fileExists(dataLibrary)
    }
}
