import AppKit
import Foundation
import SpotifyNowShared

enum SpotifyProcess {
    static var isInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifyIdentity.bundleID) != nil
    }

    static var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: SpotifyIdentity.bundleID).isEmpty
    }

    static func openOrDownload() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SpotifyIdentity.bundleID) {
            NSWorkspace.shared.open(url)
        } else if let download = URL(string: "https://www.spotify.com/download/mac/") {
            NSWorkspace.shared.open(download)
        }
    }
}

enum SystemLinks {
    static func openAutomation() {
        open([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Automation",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
        ])
    }

    static func openLoginItems() {
        open([
            "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
            "x-apple.systempreferences:com.apple.settings.General?LoginItems",
        ])
    }

    private static func open(_ candidates: [String]) {
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
