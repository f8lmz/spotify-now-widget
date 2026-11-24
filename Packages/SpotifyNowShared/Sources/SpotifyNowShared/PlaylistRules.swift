import Foundation

public enum TrackSave: Equatable, Sendable {
    case track(uri: String)
    case rejected(String)

    public static func classify(trackID: String) -> TrackSave {
        let trimmed = trackID.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .rejected("Nothing is playing that can be saved.")
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("spotify:local:") {
            return .rejected("Local files can’t be added with the Spotify API.")
        }
        if lower.hasPrefix("spotify:episode:") {
            return .rejected("Podcast episodes can’t be added to a playlist here.")
        }
        let trackPrefix = "spotify:track:"
        if lower.hasPrefix(trackPrefix) {
            let id = trimmed.dropFirst(trackPrefix.count)
            if id.isEmpty || id.contains(":") {
                return .rejected("This isn’t a Spotify song, so it can’t be added to a playlist.")
            }
            return .track(uri: "spotify:track:\(id)")
        }
        return .rejected("This isn’t a Spotify song, so it can’t be added to a playlist.")
    }
}

public struct PlaylistCandidate: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var ownerID: String
    public var collaborative: Bool
    public var imageURL: String?
    public var trackCount: Int

    public init(
        id: String,
        name: String,
        ownerID: String,
        collaborative: Bool,
        imageURL: String? = nil,
        trackCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.collaborative = collaborative
        self.imageURL = imageURL
        self.trackCount = trackCount
    }

    public func canEdit(userID: String) -> Bool {
        ownerID == userID || collaborative
    }
}

public enum SpotifyFailureCopy {
    /// Turns a Spotify HTTP error into a sentence a person can act on.
    /// Development-mode apps were pointed at `/playlists/{id}/items` in February 2026;
    /// the old `/tracks` address answers 403 with the body "Forbidden".
    public static func describe(status: Int, spotifyMessage: String) -> String {
        let body = spotifyMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let said = body.isEmpty ? "no details" : body
        guard status == 403 else {
            return "Spotify said: \(said) (HTTP \(status))."
        }
        let lower = body.lowercased()
        if lower.contains("scope") || lower.contains("insufficient") {
            return "Spotify said: \(said) (HTTP 403). Sign in again and allow playlist changes. Public playlists need playlist-modify-public, and private ones need playlist-modify-private."
        }
        return "Spotify said: \(said) (HTTP 403). In development mode the app owner needs Spotify Premium, and your account must be listed under the app’s User Management. You can only change playlists you own or collaborate on."
    }
}

public enum PlaylistCover {
    public static func preferredURL(_ images: [(url: String, width: Int?)]) -> String? {
        let usable = images.filter { !$0.url.isEmpty }
        let largeEnough = usable.filter { ($0.width ?? 0) >= 64 }
        if let best = largeEnough.min(by: { ($0.width ?? Int.max) < ($1.width ?? Int.max) }) {
            return best.url
        }
        return usable.first?.url
    }
}

public enum PlaylistEditing {
    /// Playlists the signed-in user owns, plus collaborative playlists they can edit.
    public static func editable(_ playlists: [PlaylistCandidate], userID: String) -> [PlaylistCandidate] {
        playlists
            .filter { !$0.id.isEmpty && !$0.name.isEmpty && $0.canEdit(userID: userID) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
