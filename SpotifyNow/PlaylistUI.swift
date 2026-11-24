import AppKit
import SwiftUI
import SpotifyNowShared

struct PlaylistList: View {
    var account: SpotifyAccount
    var onPick: (PlaylistCandidate) -> Void

    var body: some View {
        Group {
            if account.clientID.isEmpty {
                Button("Set Client ID…") { SettingsPanel.show() }
                    .buttonStyle(.bordered)
            } else if !account.isSignedIn {
                Button("Sign in to Spotify…") { account.signIn() }
                    .buttonStyle(.borderedProminent)
                    .tint(.nowGreen)
            } else if account.isLoadingPlaylists && account.playlists.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading playlists…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if account.playlists.isEmpty {
                Text("No playlists you can edit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(account.playlists) { playlist in
                            Button {
                                onPick(playlist)
                            } label: {
                                HStack {
                                    Text(playlist.name)
                                        .lineLimit(1)
                                    Spacer(minLength: 8)
                                    if playlist.collaborative && playlist.ownerID != account.userID {
                                        Text("Shared")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }
}

struct SpotifySettingsView: View {
    @State private var clientID = SpotifyAccount.shared.clientID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spotify account")
                .font(.headline)
            Text("Create an app at developer.spotify.com and paste its Client ID. Register this redirect URI exactly:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(SpotifyOAuth.redirectURI)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            TextField("Client ID", text: $clientID)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save") {
                    SpotifyAccount.shared.saveClientID(clientID)
                }
                if SpotifyAccount.shared.isSignedIn {
                    Button("Sign Out") { SpotifyAccount.shared.signOut() }
                } else {
                    Button("Sign In") {
                        SpotifyAccount.shared.saveClientID(clientID)
                        SpotifyAccount.shared.signIn()
                    }
                    .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Spacer()
            }
            if let name = SpotifyAccount.shared.displayName ?? SpotifyAccount.shared.userID, SpotifyAccount.shared.isSignedIn {
                Text("Signed in as \(name).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let status = SpotifyAccount.shared.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

struct PlaylistPickerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add to Playlist")
                .font(.headline)
            Text(trackLine)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            PlaylistList(account: SpotifyAccount.shared) { playlist in
                Task { await SpotifyAccount.shared.addCurrentTrack(to: playlist) }
            }
            if let status = SpotifyAccount.shared.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Spotify Account…") { SettingsPanel.show() }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                Spacer()
                Button("Refresh") {
                    Task { await SpotifyAccount.shared.refreshPlaylistsIfNeeded(force: true) }
                }
                .controlSize(.small)
                .disabled(!SpotifyAccount.shared.isSignedIn)
            }
        }
        .padding(16)
        .frame(width: 300)
        .task {
            await SpotifyAccount.shared.refreshPlaylistsIfNeeded(force: true)
        }
    }

    private var trackLine: String {
        guard let playback = PlaybackMonitor.shared.snapshot.playback, !playback.title.isEmpty else {
            return "Nothing is playing."
        }
        if playback.artist.isEmpty { return playback.title }
        return "\(playback.title) — \(playback.artist)"
    }
}

@MainActor
enum SettingsPanel {
    private static var panel: NSPanel?

    static func show() {
        let panel = ensure()
        placeNearMenuBar(panel, height: 280)
        panel.orderFrontRegardless()
        NSApp.activate()
    }

    private static func ensure() -> NSPanel {
        if let panel { return panel }
        let host = NSHostingView(rootView: SpotifySettingsView())
        let panel = makePanel(title: "Spotify Account", content: host)
        self.panel = panel
        return panel
    }
}

@MainActor
enum PlaylistPanel {
    private static var panel: NSPanel?

    static func show() {
        let panel = ensure()
        placeNearMenuBar(panel, height: 420)
        panel.orderFrontRegardless()
        NSApp.activate()
        Task { await SpotifyAccount.shared.refreshPlaylistsIfNeeded(force: true) }
    }

    private static func ensure() -> NSPanel {
        if let panel { return panel }
        let host = NSHostingView(rootView: PlaylistPickerView())
        let panel = makePanel(title: "Add to Playlist", content: host)
        self.panel = panel
        return panel
    }
}

@MainActor
private func makePanel(title: String, content: NSView) -> NSPanel {
    let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 320, height: 360),
        styleMask: [.titled, .closable, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    panel.title = title
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    content.autoresizingMask = [.width, .height]
    panel.contentView = content
    return panel
}

@MainActor
private func placeNearMenuBar(_ panel: NSPanel, height: CGFloat) {
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
    let width: CGFloat = 320
    let frame = NSRect(
        x: screen.maxX - width - 16,
        y: screen.maxY - height - 8,
        width: width,
        height: height
    )
    panel.setFrame(frame, display: true)
}

enum AppURLRouter {
    @MainActor
    static func handle(_ url: URL) async {
        guard url.scheme?.lowercased() == "spotifynow" else { return }
        switch url.host?.lowercased() {
        case "callback":
            await SpotifyAccount.shared.handleCallback(url)
        case "add-to-playlist":
            PlaylistPanel.show()
        default:
            break
        }
    }
}
