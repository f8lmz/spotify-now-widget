import Foundation

public struct TimelinePoint: Equatable, Sendable {
    public var date: Date
    public var presentation: WidgetPresentation

    public init(date: Date, presentation: WidgetPresentation) {
        self.date = date
        self.presentation = presentation
    }
}

public struct TimelinePlan: Equatable, Sendable {
    public var entries: [TimelinePoint]
    public var reloadAfter: Date

    public init(entries: [TimelinePoint], reloadAfter: Date) {
        self.entries = entries
        self.reloadAfter = reloadAfter
    }
}

public enum TimelinePlanner {
    public static let playingStep: TimeInterval = 1
    public static let playingHorizon: TimeInterval = 60
    public static let idleReload: TimeInterval = 30
    public static let staleAfter: TimeInterval = 20

    public static func plan(snapshot: NowPlayingSnapshot?, now: Date) -> TimelinePlan {
        let current = WidgetPresentationBuilder.make(snapshot: snapshot, at: now)
        guard current.phase == .track, current.isPlaying, let playback = snapshot?.playback else {
            return TimelinePlan(
                entries: [TimelinePoint(date: now, presentation: current)],
                reloadAfter: now.addingTimeInterval(idleReload)
            )
        }

        var entries: [TimelinePoint] = []
        var offset: TimeInterval = 0
        while offset <= playingHorizon + 0.001 {
            let date = now.addingTimeInterval(offset)
            let presentation = WidgetPresentation(
                phase: .track,
                title: playback.title,
                artist: playback.artist,
                album: playback.album,
                isPlaying: true,
                position: playback.extrapolatedPosition(at: date),
                duration: playback.duration,
                hasArtwork: playback.hasArtwork,
                trackID: playback.trackID
            )
            entries.append(TimelinePoint(date: date, presentation: presentation))
            offset += playingStep
        }
        return TimelinePlan(
            entries: entries,
            reloadAfter: now.addingTimeInterval(playingHorizon)
        )
    }
}
