import AppKit
import SwiftUI
import SpotifyNowShared

struct MenuPanel: View {
    var monitor: PlaybackMonitor
    @State private var launchAtLogin = false
    @State private var loginMessage: String?
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if monitor.snapshot.sourceStatus == .permissionNeeded {
                permissionBanner
            } else if let readError = monitor.lastError, !readError.isEmpty {
                readErrorBanner(readError)
            }
            player
            Text(statusLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            settings
            widgetHint
            footer
        }
        .padding(16)
        .frame(width: 308)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            loginMessage = LaunchAtLogin.message
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Spotify Now")
                .font(.headline)
            Spacer()
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel(monitor.isPlaying ? "Playing" : "Not playing")
        }
    }

    private var dotColor: Color {
        if monitor.snapshot.sourceStatus == .permissionNeeded || monitor.lastError != nil { return .orange }
        if monitor.isPlaying { return .nowGreen }
        return .secondary.opacity(0.45)
    }

    private func readErrorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Couldn’t read Spotify")
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Allow Spotify control")
                .font(.subheadline.weight(.semibold))
            Text("Click OK if macOS asks. If you already dismissed it, turn Spotify Now on for Spotify in Automation settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open Settings") { SystemLinks.openAutomation() }
                Button("Try Again") { monitor.retryPermission() }
            }
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var player: some View {
        if let playback = monitor.snapshot.playback {
            HStack(alignment: .center, spacing: 12) {
                cover(seed: playback.trackID.isEmpty ? playback.title : playback.trackID, side: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playback.title.isEmpty ? "Unknown title" : playback.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if !playback.artist.isEmpty {
                        Text(playback.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !playback.album.isEmpty {
                        Text(playback.album)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            progress(playback)
            transport
        } else {
            HStack(spacing: 12) {
                cover(seed: monitor.snapshot.sourceStatus.rawValue, side: 48)
                Text(emptyTitle)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            Button(monitor.snapshot.sourceStatus == .spotifyMissing ? "Get Spotify" : "Play") {
                if monitor.snapshot.sourceStatus == .spotifyMissing {
                    SpotifyProcess.openOrDownload()
                } else {
                    monitor.perform(.playPause)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.nowGreen)
        }
    }

    private func progress(_ playback: Playback) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = playback.extrapolatedPosition(at: context.date)
            VStack(spacing: 4) {
                if playback.duration > 1 {
                    PlaybackBar(
                        fraction: position / playback.duration,
                        tint: .nowGreen,
                        track: .primary.opacity(0.14)
                    )
                }
                HStack {
                    Text(formatPlaybackTime(position))
                    Spacer()
                    Text(formatPlaybackTime(playback.duration))
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
    }

    private var transport: some View {
        HStack(spacing: 18) {
            Spacer()
            menuTransport("backward.fill", "Previous") { monitor.perform(.previous) }
            menuTransport(monitor.isPlaying ? "pause.fill" : "play.fill", monitor.isPlaying ? "Pause" : "Play", prominent: true) {
                monitor.perform(.playPause)
            }
            menuTransport("forward.fill", "Next") { monitor.perform(.next) }
            Spacer()
        }
    }

    private func menuTransport(_ symbol: String, _ label: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 14 : 12, weight: .bold))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(width: prominent ? 36 : 32, height: prominent ? 36 : 32)
                .background {
                    if prominent {
                        Circle().fill(Color.nowGreen)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func cover(seed: String, side: CGFloat) -> some View {
        Group {
            if let artwork = monitor.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                CoverGradient(seed: seed)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin },
                set: { newValue in
                    do {
                        try LaunchAtLogin.setEnabled(newValue)
                        loginMessage = LaunchAtLogin.message
                    } catch {
                        loginMessage = error.localizedDescription
                    }
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
            ))
            if let loginMessage {
                Text(loginMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if LaunchAtLogin.needsApproval {
                    Button("Open Login Items") { SystemLinks.openLoginItems() }
                        .controlSize(.small)
                }
            }
            if AppInstaller.isRunningFromXcode {
                Text("This copy is the temporary Xcode build. Install it into Applications for everyday use.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Install in Applications") { install() }
            } else if AppInstaller.isRunningInstalledCopy {
                Text("Running from Applications.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var widgetHint: some View {
        Text("Desktop widget: right-click the desktop, choose Edit Widgets, then Spotify Now. It also appears in Notification Center.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack {
            Button(didCopy ? "Copied" : "Copy Diagnostics") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(monitor.diagnosticsText, forType: .string)
                didCopy = true
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            Spacer()
            Button("Instructions") {
                NSApp.activate()
                Welcome.present()
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
                .controlSize(.small)
        }
    }

    private var emptyTitle: String {
        if !monitor.hasLiveReading {
            return monitor.lastError == nil ? "Checking Spotify…" : "Spotify didn’t answer"
        }
        switch monitor.snapshot.sourceStatus {
        case .spotifyMissing: return "Spotify isn’t installed"
        case .permissionNeeded: return "Waiting for permission"
        case .ok:
            return monitor.snapshot.spotifyRunning ? "Nothing playing" : "Spotify is closed"
        }
    }

    private var statusLine: String {
        if !monitor.hasLiveReading {
            return monitor.lastError == nil ? "One moment." : "Spotify Now will try again in a few seconds."
        }
        switch monitor.snapshot.sourceStatus {
        case .spotifyMissing:
            return "Install the Spotify desktop app, then come back here."
        case .permissionNeeded:
            return "The widget can’t see Spotify until this app is allowed to control it."
        case .ok:
            break
        }
        let prefix: String
        if !monitor.snapshot.spotifyRunning {
            prefix = "Open Spotify and press play."
        } else if monitor.snapshot.playback == nil {
            prefix = "Spotify is open, and nothing is playing."
        } else if monitor.isPlaying {
            prefix = "Playing in Spotify."
        } else {
            prefix = "Paused in Spotify."
        }
        if monitor.shareOK {
            return prefix + " The desktop widget can show this."
        }
        return prefix + " Add the widget once so it can connect."
    }

    private func install() {
        if !AppInstaller.otherRunningCopies().isEmpty {
            let alert = NSAlert()
            alert.messageText = "Quit the other Spotify Now first"
            alert.informativeText = "Another copy is already running, so this one can’t replace it. Quit that copy from its menu bar icon, then install again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        do {
            try AppInstaller.install()
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t install"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Installed in Applications"
        alert.informativeText = "Open that copy now? This Xcode copy will quit, so you don’t get two music notes in the menu bar."
        alert.addButton(withTitle: "Open and Quit")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(AppInstaller.installedURL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                NSApp.terminate(nil)
            }
        }
    }
}
