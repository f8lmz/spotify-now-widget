import XCTest
@testable import SpotifyNowShared

final class SpotifyScriptTests: XCTestCase {
    func testParsesPlayingTrack() {
        let raw = fields([
            "playing",
            "spotify:track:abc",
            "Night Drive",
            "Silver Line",
            "Coastal",
            "214000",
            "74000",
            "https://i.scdn.co/image/abc",
        ])
        guard case .track(let track) = SpotifyScriptCodec.parse(raw) else {
            return XCTFail("expected a track")
        }
        XCTAssertTrue(track.isPlaying)
        XCTAssertEqual(track.trackID, "spotify:track:abc")
        XCTAssertEqual(track.title, "Night Drive")
        XCTAssertEqual(track.artist, "Silver Line")
        XCTAssertEqual(track.album, "Coastal")
        XCTAssertEqual(track.duration, 214, accuracy: 0.001)
        XCTAssertEqual(track.position, 74, accuracy: 0.001)
        XCTAssertEqual(track.artworkURL?.absoluteString, "https://i.scdn.co/image/abc")
    }

    func testParsesPausedAndStopped() {
        let paused = fields(["paused", "id", "Title", "Artist", "Album", "10000", "2500", ""])
        guard case .track(let track) = SpotifyScriptCodec.parse(paused) else {
            return XCTFail("expected a paused track")
        }
        XCTAssertFalse(track.isPlaying)
        XCTAssertNil(track.artworkURL)
        XCTAssertEqual(SpotifyScriptCodec.parse("stopped"), .stopped)
        XCTAssertEqual(SpotifyScriptCodec.parse("not_running\n"), .notRunning)
        XCTAssertEqual(SpotifyScriptCodec.parse("unavailable"), .unavailable)
    }

    func testAcceptsThousandsSeparatorsAndTrailingZero() {
        let raw = fields(["playing", "id", "T", "A", "L", "10.000.000", "215000.0", "missing value"])
        guard case .track(let track) = SpotifyScriptCodec.parse(raw) else {
            return XCTFail("expected a track")
        }
        XCTAssertEqual(track.duration, 10_000, accuracy: 0.001)
        XCTAssertEqual(track.position, 215, accuracy: 0.001)
        XCTAssertNil(track.artworkURL)
    }

    func testClampsPositionToDuration() {
        let raw = fields(["playing", "id", "T", "A", "L", "5000", "9000", ""])
        guard case .track(let track) = SpotifyScriptCodec.parse(raw) else {
            return XCTFail("expected a track")
        }
        XCTAssertEqual(track.position, 5, accuracy: 0.001)
    }

    func testRejectsMalformedRecords() {
        XCTAssertEqual(SpotifyScriptCodec.parse(""), .malformed)
        XCTAssertEqual(SpotifyScriptCodec.parse("playing|||only-three"), .malformed)
        XCTAssertEqual(SpotifyScriptCodec.parse("dancing|||x"), .malformed)
        let badNumber = fields(["playing", "id", "T", "A", "L", "nope", "1", ""])
        XCTAssertEqual(SpotifyScriptCodec.parse(badNumber), .malformed)
    }

    func testCleansNewlinesAndMissingValue() {
        let raw = fields(["playing", "id", "Line\nBreak", "missing value", "Album", "1000", "0", "http://cdn.example/art"])
        guard case .track(let track) = SpotifyScriptCodec.parse(raw) else {
            return XCTFail("expected a track")
        }
        XCTAssertEqual(track.title, "Line Break")
        XCTAssertEqual(track.artist, "")
        XCTAssertEqual(track.artworkURL?.host, "cdn.example")
    }

    func testScriptUsesTheSameDelimiterAndIntegerFormatting() {
        let source = SpotifyAppleScript.fetchNowPlaying
        XCTAssertTrue(source.contains(SpotifyScriptCodec.delimiter))
        XCTAssertTrue(source.contains("player state is playing"))
        XCTAssertTrue(source.contains("as integer"))
        XCTAssertTrue(source.contains("rounding toward zero"))
        XCTAssertTrue(source.contains("my sanitize("))
        let scripts = [
            source,
            SpotifyAppleScript.fetchArtwork,
            SpotifyAppleScript.play,
            SpotifyAppleScript.playPause,
            SpotifyAppleScript.nextTrack,
            SpotifyAppleScript.previousTrack,
        ]
        for script in scripts {
            for body in Self.spotifyTellBodies(script) {
                XCTAssertFalse(
                    body.contains("sanitize"),
                    "Handler call inside tell application \"Spotify\" is sent to Spotify: \(body)"
                )
            }
        }
        XCTAssertEqual(SpotifyAppleScript.script(for: .playPause, launchIfNeeded: false), SpotifyAppleScript.playPause)
        let play = SpotifyAppleScript.script(for: .playPause, launchIfNeeded: true)
        XCTAssertEqual(play, SpotifyAppleScript.play)
        XCTAssertFalse(play.contains("playpause"))
        XCTAssertTrue(SpotifyAppleScript.script(for: .next, launchIfNeeded: false).contains("next track"))
        XCTAssertTrue(SpotifyAppleScript.script(for: .previous, launchIfNeeded: false).contains("previous track"))
    }

    func testArtworkURLAttemptsPreferHTTPS() {
        let http = URL(string: "http://i.scdn.co/image/abc")!
        let attempts = ArtworkURL.attempts(for: http)
        XCTAssertEqual(attempts.map(\.scheme), ["https", "http"])
        let https = URL(string: "https://i.scdn.co/image/abc")!
        XCTAssertEqual(ArtworkURL.attempts(for: https).count, 1)
        XCTAssertTrue(ArtworkURL.attempts(for: URL(string: "file:///tmp/a.jpg")!).isEmpty)
    }

    private func fields(_ parts: [String]) -> String {
        parts.joined(separator: SpotifyScriptCodec.delimiter)
    }

    /// Bodies of `tell application "Spotify" ... end tell`, plus one-line `tell ... to` commands.
    private static func spotifyTellBodies(_ source: String) -> [String] {
        var bodies: [String] = []
        var rest = source[...]
        let opener = "tell application \"Spotify\""
        while let start = rest.range(of: opener) {
            let after = rest[start.upperBound...]
            if after.hasPrefix(" to ") {
                let line = after.prefix { $0 != "\n" }
                bodies.append(String(line))
                rest = after[line.endIndex...]
                continue
            }
            guard let end = after.range(of: "\nend tell") else { break }
            bodies.append(String(after[..<end.lowerBound]))
            rest = after[end.upperBound...]
        }
        return bodies
    }
}
