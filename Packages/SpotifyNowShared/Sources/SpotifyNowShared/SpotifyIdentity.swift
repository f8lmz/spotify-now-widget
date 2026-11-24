import Foundation

public enum SpotifyIdentity {
    /// Bundle id of the official Spotify desktop app.
    public static let bundleID = "com.spotify.client"
    /// Posted by Spotify when the track, play state, or position changes.
    public static let playbackNotification = "com.spotify.client.PlaybackStateChanged"
}

public enum SpotifyNowWidgetKind {
    public static let nowPlaying = "SpotifyNow"
}

public enum PlaybackCommand: String, Codable, Sendable, CaseIterable {
    case playPause
    case next
    case previous
}

public struct CommandEnvelope: Codable, Equatable, Sendable {
    public var id: UUID
    public var command: PlaybackCommand
    public var createdAt: Date

    public init(id: UUID, command: PlaybackCommand, createdAt: Date) {
        self.id = id
        self.command = command
        self.createdAt = createdAt
    }

    /// Ignore commands that already ran, or that sat on disk across a relaunch.
    public func shouldExecute(at now: Date, handled: Set<UUID>, maxAge: TimeInterval = 15) -> Bool {
        if handled.contains(id) { return false }
        if now.timeIntervalSince(createdAt) > maxAge { return false }
        return true
    }
}
