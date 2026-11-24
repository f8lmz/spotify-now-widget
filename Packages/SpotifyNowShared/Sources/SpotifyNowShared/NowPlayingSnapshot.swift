import Foundation

public enum SourceStatus: String, Codable, Sendable {
    case ok
    case permissionNeeded
    case spotifyMissing
}

public struct Playback: Codable, Equatable, Sendable {
    public var trackID: String
    public var title: String
    public var artist: String
    public var album: String
    /// Length in seconds. Zero when Spotify does not report one.
    public var duration: TimeInterval
    /// Position in seconds at `positionDate`.
    public var position: TimeInterval
    public var positionDate: Date
    public var isPlaying: Bool
    public var hasArtwork: Bool

    public init(
        trackID: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        position: TimeInterval,
        positionDate: Date,
        isPlaying: Bool,
        hasArtwork: Bool
    ) {
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.positionDate = positionDate
        self.isPlaying = isPlaying
        self.hasArtwork = hasArtwork
    }

    public func extrapolatedPosition(at date: Date) -> TimeInterval {
        let raw: TimeInterval
        if isPlaying {
            raw = position + date.timeIntervalSince(positionDate)
        } else {
            raw = position
        }
        let clamped = max(0, raw)
        if duration > 0 {
            return min(clamped, duration)
        }
        return clamped
    }
}

public struct NowPlayingSnapshot: Codable, Equatable, Sendable {
    public static let currentSchema = 1

    public var schemaVersion: Int
    public var updatedAt: Date
    public var spotifyRunning: Bool
    public var sourceStatus: SourceStatus
    public var playback: Playback?

    public init(
        schemaVersion: Int = NowPlayingSnapshot.currentSchema,
        updatedAt: Date,
        spotifyRunning: Bool,
        sourceStatus: SourceStatus,
        playback: Playback?
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.spotifyRunning = spotifyRunning
        self.sourceStatus = sourceStatus
        self.playback = playback
    }

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

public enum SnapshotDelta {
    /// A seek, or a drift correction, big enough to redraw the widget.
    public static let seekThreshold: TimeInterval = 2.5

    public static func requiresWidgetReload(from old: NowPlayingSnapshot?, to new: NowPlayingSnapshot) -> Bool {
        guard let old else { return true }
        if old.spotifyRunning != new.spotifyRunning { return true }
        if old.sourceStatus != new.sourceStatus { return true }
        guard let previous = old.playback else { return new.playback != nil }
        guard let current = new.playback else { return true }
        if previous.trackID != current.trackID { return true }
        if previous.title != current.title { return true }
        if previous.artist != current.artist { return true }
        if previous.album != current.album { return true }
        if previous.isPlaying != current.isPlaying { return true }
        if previous.hasArtwork != current.hasArtwork { return true }
        if abs(previous.duration - current.duration) > 0.5 { return true }
        let expected = previous.extrapolatedPosition(at: current.positionDate)
        if abs(expected - current.position) > seekThreshold { return true }
        return false
    }
}
