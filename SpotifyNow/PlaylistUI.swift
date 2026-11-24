import AppKit
import SwiftUI
import SpotifyNowShared

struct PlaylistList: View {
    var account: SpotifyAccount
    var compact: Bool
    var query: String
    var onPick: (PlaylistCandidate) -> Void

    private var filtered: [PlaylistCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return account.playlists }
        return account.playlists.filter { $0.name.localizedStandardContains(trimmed) }
    }

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
            } else if filtered.isEmpty {
                Text(account.playlists.isEmpty ? "No playlists you can edit." : "No playlists match that search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: compact ? 2 : 6) {
                        ForEach(filtered) { playlist in
                            PlaylistRow(
                                playlist: playlist,
                                compact: compact,
                                isOwned: playlist.ownerID == account.userID,
                                isAdding: account.addingPlaylistID == playlist.id,
                                isAdded: account.addedPlaylistIDs.contains(playlist.id)
                            ) {
                                onPick(playlist)
                            }
                            .task {
                                await PlaylistArtwork.shared.load(id: playlist.id, urlString: playlist.imageURL)
                            }
                        }
                    }
                    .padding(.vertical, compact ? 0 : 4)
                }
                .frame(maxHeight: compact ? 240 : .infinity)
            }
        }
    }
}

private struct PlaylistRow: View {
    var playlist: PlaylistCandidate
    var compact: Bool
    var isOwned: Bool
    var isAdding: Bool
    var isAdded: Bool
    var action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 8 : 12) {
                PlaylistCoverView(id: playlist.id, seed: playlist.name, side: compact ? 24 : 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.name)
                        .font(compact ? .callout : .body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !compact {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if isAdding {
                    ProgressView().controlSize(.small)
                } else if isAdded {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.nowGreen)
                } else if compact && !isOwned && playlist.collaborative {
                    Text("Shared")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, compact ? 4 : 8)
            .frame(maxWidth: .infinity, minHeight: compact ? 32 : 56, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(hovered && !compact ? Color.primary.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel("Add to \(playlist.name)")
    }

    private var subtitle: String {
        let songs = playlist.trackCount == 1 ? "1 song" : "\(playlist.trackCount) songs"
        if playlist.collaborative && !isOwned {
            return "\(songs) · Shared"
        }
        return songs
    }
}

private struct PlaylistCoverView: View {
    var id: String
    var seed: String
    var side: CGFloat

    var body: some View {
        Group {
            if let image = PlaylistArtwork.shared.image(for: id) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                CoverGradient(seed: seed)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side > 30 ? 8 : 5, style: .continuous))
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
        .frame(width: 340)
    }
}

struct PlaylistPickerView: View {
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nowPlayingHeader
            TextField("Search playlists", text: $query)
                .textFieldStyle(.roundedBorder)
            PlaylistList(account: SpotifyAccount.shared, compact: false, query: query) { playlist in
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
        .frame(width: 360)
        .task {
            await SpotifyAccount.shared.refreshPlaylistsIfNeeded(force: true)
        }
    }

    private var nowPlayingHeader: some View {
        let playback = PlaybackMonitor.shared.snapshot.playback
        return HStack(spacing: 10) {
            Group {
                if let artwork = PlaybackMonitor.shared.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    CoverGradient(seed: playback?.title ?? "empty")
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(playback?.title.isEmpty == false ? playback!.title : "Nothing playing")
                    .font(.headline)
                    .lineLimit(1)
                Text(playback?.artist ?? "Play a song in Spotify")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

@MainActor
enum SettingsPanel {
    private static var panel: NSPanel?

    static func show() {
        let panel = ensure()
        placeNearMenuBar(panel, width: 372, height: 300)
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
        placeNearMenuBar(panel, width: 392, height: 560)
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
        contentRect: NSRect(x: 0, y: 0, width: 392, height: 560),
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
private func placeNearMenuBar(_ panel: NSPanel, width: CGFloat, height: CGFloat) {
    let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
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
