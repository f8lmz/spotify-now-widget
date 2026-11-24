import XCTest
@testable import SpotifyNowShared

final class PlaybackModelTests: XCTestCase {
    func testExtrapolationWhilePlayingAndPaused() {
        let start = Date(timeIntervalSince1970: 1_000)
        var playback = samplePlayback(position: 10, at: start, duration: 50, isPlaying: true)
        XCTAssertEqual(playback.extrapolatedPosition(at: start.addingTimeInterval(5)), 15, accuracy: 0.001)
        XCTAssertEqual(playback.extrapolatedPosition(at: start.addingTimeInterval(100)), 50, accuracy: 0.001)
        playback.isPlaying = false
        XCTAssertEqual(playback.extrapolatedPosition(at: start.addingTimeInterval(5)), 10, accuracy: 0.001)
    }

    func testReloadIgnoresHeartbeatAndCatchesSeek() {
        let start = Date(timeIntervalSince1970: 5_000)
        let old = NowPlayingSnapshot(
            updatedAt: start,
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: samplePlayback(position: 10, at: start, duration: 200, isPlaying: true)
        )
        var heartbeat = old
        heartbeat.updatedAt = start.addingTimeInterval(4)
        heartbeat.playback?.position = 14
        heartbeat.playback?.positionDate = start.addingTimeInterval(4)
        XCTAssertFalse(SnapshotDelta.requiresWidgetReload(from: old, to: heartbeat))

        var seeked = heartbeat
        seeked.playback?.position = 40
        XCTAssertTrue(SnapshotDelta.requiresWidgetReload(from: old, to: seeked))

        var paused = heartbeat
        paused.playback?.isPlaying = false
        XCTAssertTrue(SnapshotDelta.requiresWidgetReload(from: old, to: paused))
        XCTAssertTrue(SnapshotDelta.requiresWidgetReload(from: nil, to: old))
    }

    func testPhasesAndStaleFile() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: nil, at: now).phase, .waitingForApp)

        let fresh = NowPlayingSnapshot(
            updatedAt: now.addingTimeInterval(-19),
            spotifyRunning: false,
            sourceStatus: .ok,
            playback: nil
        )
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: fresh, at: now).phase, .spotifyClosed)

        let stale = NowPlayingSnapshot(
            updatedAt: now.addingTimeInterval(-21),
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: samplePlayback(position: 1, at: now, duration: 10, isPlaying: true)
        )
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: stale, at: now).phase, .appNotRunning)

        let denied = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: true,
            sourceStatus: .permissionNeeded,
            playback: nil
        )
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: denied, at: now).phase, .permissionNeeded)

        let missing = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: false,
            sourceStatus: .spotifyMissing,
            playback: nil
        )
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: missing, at: now).phase, .spotifyMissing)

        let idle = NowPlayingSnapshot(updatedAt: now, spotifyRunning: true, sourceStatus: .ok, playback: nil)
        XCTAssertEqual(WidgetPresentationBuilder.make(snapshot: idle, at: now).phase, .nothingPlaying)
    }

    func testPlayingTimelineAdvancesAndPausesOnce() {
        let now = Date(timeIntervalSince1970: 10_000)
        let snapshot = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: samplePlayback(position: 10, at: now, duration: 30, isPlaying: true)
        )
        let plan = TimelinePlanner.plan(snapshot: snapshot, now: now)
        XCTAssertEqual(plan.entries.count, 61)
        XCTAssertEqual(plan.entries.first?.presentation.position ?? -1, 10, accuracy: 0.001)
        XCTAssertEqual(plan.entries.last?.presentation.position ?? -1, 30, accuracy: 0.001)
        XCTAssertEqual(plan.reloadAfter, now.addingTimeInterval(60))

        var paused = snapshot
        paused.playback?.isPlaying = false
        let idle = TimelinePlanner.plan(snapshot: paused, now: now)
        XCTAssertEqual(idle.entries.count, 1)
        XCTAssertEqual(idle.reloadAfter, now.addingTimeInterval(TimelinePlanner.idleReload))
    }

    func testTimeFormatAndCoverHue() {
        XCTAssertEqual(formatPlaybackTime(0), "0:00")
        XCTAssertEqual(formatPlaybackTime(5), "0:05")
        XCTAssertEqual(formatPlaybackTime(65), "1:05")
        XCTAssertEqual(formatPlaybackTime(3661), "1:01:01")
        XCTAssertEqual(formatPlaybackTime(-4), "0:00")
        XCTAssertEqual(formatPlaybackTime(.nan), "0:00")
        let hue = CoverHueMaker.hues(for: "spotify:track:abc")
        XCTAssertEqual(hue, CoverHueMaker.hues(for: "spotify:track:abc"))
        XCTAssertNotEqual(hue, CoverHueMaker.hues(for: "other"))
        XCTAssertGreaterThanOrEqual(hue.primary, 0)
        XCTAssertLessThan(hue.primary, 1)
    }

    func testPlaceholderOpensNoSpotifyLink() {
        let preview = WidgetPresentation.placeholder()
        XCTAssertEqual(preview.phase, .track)
        XCTAssertNil(preview.spotifyURL)
        XCTAssertEqual(preview.fraction ?? 0, 74 / 214, accuracy: 0.0001)
    }

    private func samplePlayback(position: TimeInterval, at date: Date, duration: TimeInterval, isPlaying: Bool) -> Playback {
        Playback(
            trackID: "spotify:track:abc",
            title: "Night Drive",
            artist: "Silver Line",
            album: "Coastal",
            duration: duration,
            position: position,
            positionDate: date,
            isPlaying: isPlaying,
            hasArtwork: false
        )
    }
}
