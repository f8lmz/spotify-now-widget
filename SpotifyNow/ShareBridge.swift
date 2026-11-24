import Foundation
import SpotifyNowShared

/// Folders the menu bar app and the widget can both see.
enum ShareBridge {
    private static var cache: (at: Date, stores: [SharedStore])?

    static func stores() -> [SharedStore] {
        if let cache, Date().timeIntervalSince(cache.at) < 1 {
            return cache.stores
        }
        let fresh = discover()
        cache = (Date(), fresh)
        return fresh
    }

    static func paths() -> [String] {
        stores().map(\.directory.path)
    }

    private static func discover() -> [SharedStore] {
        var urls: [URL] = []
        if let group = AppGroupResolver.writableStoreURL() {
            urls.append(group)
        }
        if let widget = widgetStoreURL() {
            urls.append(widget)
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }.map(SharedStore.init(directory:))
    }

    /// The widget's own sandbox folder, used when the App Group is unavailable.
    /// Only written after macOS has created the container, and only for an
    /// extension signed by this same app.
    private static func widgetStoreURL() -> URL? {
        guard let bundleID = EmbeddedWidget.bundleID() else { return nil }
        let home = FileManager.default.homeDirectoryForCurrentUser
        guard SharedLocation.widgetContainerIsReady(home: home, widgetBundleID: bundleID, fileExists: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            return nil
        }
        let directory = SharedLocation.storeDirectory(
            in: SharedLocation.widgetApplicationSupport(home: home, widgetBundleID: bundleID)
        )
        return DirectoryAccess.isWritable(directory) ? directory : nil
    }
}

enum EmbeddedWidget {
    static func bundleID() -> String? {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return nil }
        let url = plugins.appendingPathComponent("SpotifyNowWidget.appex")
        return Bundle(url: url)?.bundleIdentifier
    }
}
