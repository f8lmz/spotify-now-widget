import AppKit
import Foundation
import SpotifyNowShared

@MainActor
@Observable
final class SpotifyAccount {
    static let shared = SpotifyAccount()

    private(set) var clientID = ""
    private(set) var userID: String?
    private(set) var displayName: String?
    private(set) var playlists: [PlaylistCandidate] = []
    private(set) var isLoadingPlaylists = false
    private(set) var statusMessage: String?
    private(set) var isAuthorizing = false
    private(set) var addingPlaylistID: String?
    private(set) var addedPlaylistIDs: Set<String> = []

    private var accessToken: String?
    private var accessExpiry = Date.distantPast
    private var refreshToken: String?
    private var refreshTask: Task<String, Error>?
    private var pendingVerifier: String?
    private var pendingState: String?
    private var grantedScopes = ""
    private var playlistsFetchedAt: Date?
    private var isAdding = false

    var isSignedIn: Bool {
        refreshToken != nil && !clientID.isEmpty
    }

    func prepare() {
        clientID = KeychainStore.load(account: AccountKey.clientID) ?? ""
        refreshToken = KeychainStore.load(account: AccountKey.refreshToken)
        grantedScopes = KeychainStore.load(account: AccountKey.scopes) ?? ""
        guard isSignedIn else { return }
        Task { await restoreSession() }
    }

    func saveClientID(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let changed = trimmed != clientID
        clientID = trimmed
        if trimmed.isEmpty {
            KeychainStore.delete(account: AccountKey.clientID)
        } else {
            KeychainStore.save(trimmed, account: AccountKey.clientID)
        }
        if changed {
            clearSession(keepClientID: true)
            statusMessage = trimmed.isEmpty ? "Enter a Spotify Client ID." : "Client ID saved. Sign in to Spotify."
        }
    }

    func signIn() {
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else {
            statusMessage = "Enter a Spotify Client ID first."
            SettingsPanel.show()
            return
        }
        let verifier = PKCE.verifier()
        let state = UUID().uuidString
        pendingVerifier = verifier
        pendingState = state
        isAuthorizing = true
        let url = SpotifyWebAPI.authorizationURL(clientID: id, verifier: verifier, state: state)
        NSWorkspace.shared.open(url)
    }

    func signOut() {
        clearSession(keepClientID: true)
        statusMessage = "Signed out of Spotify."
    }

    func handleCallback(_ url: URL) async {
        if clientID.isEmpty {
            clientID = KeychainStore.load(account: AccountKey.clientID) ?? ""
        }
        isAuthorizing = false
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }
        if let error = query("error"), !error.isEmpty {
            statusMessage = error == "access_denied" ? "Spotify sign-in was cancelled." : error
            pendingVerifier = nil
            pendingState = nil
            return
        }
        guard let code = query("code"), !code.isEmpty else {
            statusMessage = "Spotify didn’t return a sign-in code."
            return
        }
        guard query("state") == pendingState, let verifier = pendingVerifier else {
            statusMessage = "Sign-in was interrupted. Try again."
            return
        }
        pendingState = nil
        pendingVerifier = nil
        do {
            let token = try await SpotifyWebAPI.exchange(code: code, clientID: clientID, verifier: verifier)
            store(token)
            try await loadProfileAndPlaylists(force: true)
            let name = displayName ?? userID ?? "Spotify"
            statusMessage = "Signed in as \(name)."
            UserNotifier.show(title: "Signed in to Spotify", body: name)
            promptForMissingScopes()
        } catch {
            statusMessage = error.localizedDescription
            UserNotifier.show(title: "Couldn’t sign in", body: error.localizedDescription)
        }
    }

    func refreshPlaylistsIfNeeded(force: Bool) async {
        guard isSignedIn else { return }
        if !force, let playlistsFetchedAt, Date().timeIntervalSince(playlistsFetchedAt) < 45, !playlists.isEmpty {
            return
        }
        isLoadingPlaylists = true
        defer { isLoadingPlaylists = false }
        do {
            try await loadProfileAndPlaylists(force: false)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func addCurrentTrack(to playlist: PlaylistCandidate) async {
        guard !isAdding else { return }
        guard isSignedIn else {
            report(title: "Not signed in", message: "Sign in to Spotify before adding to a playlist.")
            return
        }
        let playback = PlaybackMonitor.shared.snapshot.playback
        switch TrackSave.classify(trackID: playback?.trackID ?? "") {
        case .rejected(let message):
            report(title: "Not added", message: message)
        case .track(let uri):
            let title = playback?.title.isEmpty == false ? playback!.title : "Track"
            isAdding = true
            addingPlaylistID = playlist.id
            defer {
                isAdding = false
                addingPlaylistID = nil
            }
            do {
                let token = try await validAccessToken()
                if try await SpotifyWebAPI.contains(uri: uri, playlistID: playlist.id, token: token) {
                    addedPlaylistIDs.insert(playlist.id)
                    report(title: "Already in playlist", message: "\(title) is already in \(playlist.name).")
                    return
                }
                let fresh = try await validAccessToken()
                try await SpotifyWebAPI.add(uri: uri, playlistID: playlist.id, token: fresh)
                addedPlaylistIDs.insert(playlist.id)
                report(title: "Added to \(playlist.name)", message: "Added \(title) to \(playlist.name).")
            } catch {
                report(title: "Couldn’t add to playlist", message: error.localizedDescription)
                if let api = error as? SpotifyAPIError, api.requiresReconsent {
                    promptForMissingScopes(force: true)
                }
            }
        }
    }

    private func restoreSession() async {
        do {
            _ = try await validAccessToken()
            try await loadProfileAndPlaylists(force: true)
            promptForMissingScopes()
        } catch {
            clearSession(keepClientID: true)
            statusMessage = "Spotify sign-in expired. Sign in again."
        }
    }

    private func loadProfileAndPlaylists(force: Bool) async throws {
        if !force, let playlistsFetchedAt, Date().timeIntervalSince(playlistsFetchedAt) < 45, userID != nil, !playlists.isEmpty {
            return
        }
        let token = try await validAccessToken()
        let user = try await SpotifyWebAPI.currentUser(token: token)
        userID = user.id
        displayName = user.name
        let listToken = try await validAccessToken()
        playlists = try await SpotifyWebAPI.editablePlaylists(token: listToken, userID: user.id)
        playlistsFetchedAt = Date()
    }

    private func validAccessToken() async throws -> String {
        if let accessToken, accessExpiry.timeIntervalSinceNow > 60 {
            return accessToken
        }
        if let refreshTask {
            return try await refreshTask.value
        }
        let task = Task { try await self.performRefresh() }
        refreshTask = task
        do {
            let token = try await task.value
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }

    private func performRefresh() async throws -> String {
        guard let refreshToken, !clientID.isEmpty else {
            throw SpotifyAPIError(message: "Sign in to Spotify first.", status: 0, requiresReconsent: false)
        }
        let token = try await SpotifyWebAPI.refresh(refreshToken: refreshToken, clientID: clientID)
        store(token)
        return token.accessToken
    }

    private func store(_ token: SpotifyToken) {
        accessToken = token.accessToken
        accessExpiry = token.expiresAt
        if let refresh = token.refreshToken, !refresh.isEmpty {
            refreshToken = refresh
            KeychainStore.save(refresh, account: AccountKey.refreshToken)
        }
        if let scope = token.scope, !scope.isEmpty {
            grantedScopes = scope
            KeychainStore.save(scope, account: AccountKey.scopes)
        }
    }

    private func promptForMissingScopes(force: Bool = false) {
        let granted = Set(grantedScopes.split(separator: " ").map(String.init))
        let missing = SpotifyOAuth.requiredScopes.subtracting(granted)
        guard force || (!granted.isEmpty && !missing.isEmpty) else { return }
        let alert = NSAlert()
        alert.messageText = "Spotify needs playlist permission"
        alert.informativeText = "Sign in again so Spotify can show the permission screen. Adding songs needs playlist-modify-public and playlist-modify-private."
        alert.addButton(withTitle: "Sign In")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            signIn()
        }
    }

    private func clearSession(keepClientID: Bool) {
        accessToken = nil
        accessExpiry = .distantPast
        refreshToken = nil
        userID = nil
        displayName = nil
        playlists = []
        playlistsFetchedAt = nil
        pendingState = nil
        pendingVerifier = nil
        grantedScopes = ""
        addedPlaylistIDs = []
        KeychainStore.delete(account: AccountKey.refreshToken)
        KeychainStore.delete(account: AccountKey.scopes)
        if !keepClientID {
            clientID = ""
            KeychainStore.delete(account: AccountKey.clientID)
        }
    }

    private func report(title: String, message: String) {
        statusMessage = message
        UserNotifier.show(title: title, body: message)
    }
}

private enum AccountKey {
    static let clientID = "spotify.clientID"
    static let refreshToken = "spotify.refreshToken"
    static let scopes = "spotify.scopes"
}
