import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static var message: String? {
        switch SMAppService.mainApp.status {
        case .requiresApproval:
            return "macOS still needs you to allow it under Login Items."
        case .notFound:
            return "Install Spotify Now into Applications, open that copy, then try again."
        case .enabled, .notRegistered:
            return nil
        @unknown default:
            return nil
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else if SMAppService.mainApp.status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum AppInstaller {
    static var installedURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .appendingPathComponent("Spotify Now.app", isDirectory: true)
    }

    static var isRunningInstalledCopy: Bool {
        Bundle.main.bundleURL.standardizedFileURL.path == installedURL.standardizedFileURL.path
    }

    static var isRunningFromXcode: Bool {
        Bundle.main.bundlePath.contains("/DerivedData/")
    }

    static func install() throws {
        let fileManager = FileManager.default
        let destination = installedURL
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: Bundle.main.bundleURL, to: destination)
    }

    static func otherRunningCopies() -> [NSRunningApplication] {
        let mine = Bundle.main.bundleURL.standardizedFileURL
        let identifier = Bundle.main.bundleIdentifier ?? ""
        return NSRunningApplication.runningApplications(withBundleIdentifier: identifier).filter {
            $0.bundleURL?.standardizedFileURL.path != mine.path
        }
    }
}
