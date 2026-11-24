import Foundation

public enum WidgetPhase: String, Equatable, Sendable {
    case waitingForApp
    case appNotRunning
    case permissionNeeded
    case spotifyMissing
    case spotifyClosed
    case nothingPlaying
    case track
}

public struct WidgetPresentation: Equatable, Sendable {
    public var phase: WidgetPhase
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var position: TimeInterval
    public var duration: TimeInterval
    public var hasArtwork: Bool
    public var trackID: String

    public init(
        phase: WidgetPhase,
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        position: TimeInterval,
        duration: TimeInterval,
        hasArtwork: Bool,
        trackID: String
    ) {
        self.phase = phase
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.position = position
        self.duration = duration
        self.hasArtwork = hasArtwork
        self.trackID = trackID
    }

    public var fraction: Double? {
        guard duration > 1 else { return nil }
        return min(1, max(0, position / duration))
    }

    public var spotifyURL: URL? {
        guard phase == .track, trackID.hasPrefix("spotify:") else { return nil }
        return URL(string: trackID)
    }

    public var coverSeed: String {
        if phase == .track {
            return trackID.isEmpty ? (title.isEmpty ? "track" : title) : trackID
        }
        return phase.rawValue
    }

    public static func placeholder() -> WidgetPresentation {
        WidgetPresentation(
            phase: .track,
            title: "Night Drive",
            artist: "Silver Line",
            album: "Coastal",
            isPlaying: true,
            position: 74,
            duration: 214,
            hasArtwork: false,
            trackID: "preview-night-drive"
        )
    }
}

public enum WidgetPresentationBuilder {
    public static func make(
        snapshot: NowPlayingSnapshot?,
        at date: Date,
        staleAfter: TimeInterval = TimelinePlanner.staleAfter
    ) -> WidgetPresentation {
        guard let snapshot else {
            return empty(.waitingForApp)
        }
        if date.timeIntervalSince(snapshot.updatedAt) > staleAfter {
            return empty(.appNotRunning)
        }
        switch snapshot.sourceStatus {
        case .permissionNeeded:
            return empty(.permissionNeeded)
        case .spotifyMissing:
            return empty(.spotifyMissing)
        case .ok:
            break
        }
        if !snapshot.spotifyRunning {
            return empty(.spotifyClosed)
        }
        guard let playback = snapshot.playback else {
            return empty(.nothingPlaying)
        }
        return WidgetPresentation(
            phase: .track,
            title: playback.title,
            artist: playback.artist,
            album: playback.album,
            isPlaying: playback.isPlaying,
            position: playback.extrapolatedPosition(at: date),
            duration: playback.duration,
            hasArtwork: playback.hasArtwork,
            trackID: playback.trackID
        )
    }

    private static func empty(_ phase: WidgetPhase) -> WidgetPresentation {
        WidgetPresentation(
            phase: phase,
            title: "",
            artist: "",
            album: "",
            isPlaying: false,
            position: 0,
            duration: 0,
            hasArtwork: false,
            trackID: ""
        )
    }
}

public func formatPlaybackTime(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else { return "0:00" }
    let total = max(0, Int(seconds.rounded(.down)))
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let secs = total % 60
    if hours > 0 {
        return "\(hours):\(twoDigits(minutes)):\(twoDigits(secs))"
    }
    return "\(minutes):\(twoDigits(secs))"
}

private func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
}

public struct CoverHue: Equatable, Sendable {
    public var primary: Double
    public var secondary: Double

    public init(primary: Double, secondary: Double) {
        self.primary = primary
        self.secondary = secondary
    }
}

public enum CoverHueMaker {
    /// Stable colors for a track when Spotify has no artwork.
    public static func hues(for seed: String) -> CoverHue {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        let primary = Double(hash % 360) / 360
        let secondary = Double((hash / 360) % 360) / 360
        return CoverHue(primary: primary, secondary: secondary)
    }
}
