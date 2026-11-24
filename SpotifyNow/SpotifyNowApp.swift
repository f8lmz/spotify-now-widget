import AppKit
import SwiftUI

enum Welcome {
    private static let key = "didShowWelcome.v1"

    static var needsPresentation: Bool {
        !UserDefaults.standard.bool(forKey: key)
    }

    @discardableResult
    static func presentIfNeeded() -> Bool {
        guard needsPresentation else { return false }
        UserDefaults.standard.set(true, forKey: key)
        present()
        return true
    }

    static func present() {
        let alert = NSAlert()
        alert.messageText = "Spotify Now is in the menu bar"
        alert.informativeText = """
        Look for the music note next to the clock.

        1. If macOS asks to control Spotify, click OK.
        2. Play a song in the Spotify app.
        3. Right-click the desktop, choose Edit Widgets, and add Spotify Now.

        Leave the music-note app running. The desktop widget reads from it. You can turn on Launch at login in that menu.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

@main
struct SpotifyNowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(monitor: PlaybackMonitor.shared)
        } label: {
            Image(systemName: "music.note")
                .accessibilityLabel("Spotify Now")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            NSApp.setActivationPolicy(.accessory)
            if Welcome.needsPresentation {
                NSApp.activate()
                Welcome.presentIfNeeded()
            }
            PlaybackMonitor.shared.start()
            SpotifyAccount.shared.prepare()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { @MainActor in
                await AppURLRouter.handle(url)
            }
        }
    }
}
