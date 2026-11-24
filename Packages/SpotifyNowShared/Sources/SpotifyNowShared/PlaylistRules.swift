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

    public init(id: String, name: String, ownerID: String, collaborative: Bool) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.collaborative = collaborative
    }

    public func canEdit(userID: String) -> Bool {
        ownerID == userID || collaborative
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
