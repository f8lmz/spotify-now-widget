import XCTest
@testable import SpotifyNowShared

final class PlaylistRulesTests: XCTestCase {
    func testClassifiesTracksEpisodesAndLocalFiles() {
        XCTAssertEqual(TrackSave.classify(trackID: "spotify:track:abc"), .track(uri: "spotify:track:abc"))
        XCTAssertEqual(
            TrackSave.classify(trackID: "  spotify:track:AbC12  "),
            .track(uri: "spotify:track:AbC12")
        )
        if case .rejected(let message) = TrackSave.classify(trackID: "spotify:episode:abc") {
            XCTAssertTrue(message.contains("Podcast"))
        } else {
            XCTFail("expected a podcast rejection")
        }
        if case .rejected(let message) = TrackSave.classify(trackID: "spotify:local:song") {
            XCTAssertTrue(message.contains("Local"))
        } else {
            XCTFail("expected a local-file rejection")
        }
        if case .rejected = TrackSave.classify(trackID: "") {
        } else {
            XCTFail("expected an empty-track rejection")
        }
    }

    func testEditablePlaylistsKeepOwnedAndCollaborative() {
        let me = "me"
        let lists = [
            PlaylistCandidate(id: "2", name: "New Age", ownerID: me, collaborative: false),
            PlaylistCandidate(id: "3", name: "Shared", ownerID: "other", collaborative: true),
            PlaylistCandidate(id: "1", name: "Followed", ownerID: "other", collaborative: false),
            PlaylistCandidate(id: "4", name: "Mix", ownerID: me, collaborative: true),
            PlaylistCandidate(id: "", name: "Blank", ownerID: me, collaborative: false),
        ]
        let editable = PlaylistEditing.editable(lists, userID: me)
        XCTAssertEqual(editable.map(\.name), ["Mix", "New Age", "Shared"])
    }

    func testForbiddenExplainsTheDevelopmentModeRestriction() {
        let message = SpotifyFailureCopy.describe(status: 403, spotifyMessage: "Forbidden")
        XCTAssertTrue(message.contains("Forbidden"))
        XCTAssertTrue(message.contains("User Management"))
        XCTAssertTrue(message.contains("Premium"))
        let scope = SpotifyFailureCopy.describe(status: 403, spotifyMessage: "Insufficient client scope")
        XCTAssertTrue(scope.contains("Sign in again"))
        let other = SpotifyFailureCopy.describe(status: 429, spotifyMessage: "Too many requests")
        XCTAssertTrue(other.contains("Too many requests"))
        XCTAssertFalse(other.contains("User Management"))
    }

    func testCoverPrefersTheSmallestImageThatIsStillSharp() {
        let url = PlaylistCover.preferredURL([
            (url: "https://i.scdn.co/large", width: 640),
            (url: "https://i.scdn.co/medium", width: 300),
            (url: "https://i.scdn.co/tiny", width: 64),
        ])
        XCTAssertEqual(url, "https://i.scdn.co/tiny")
        XCTAssertEqual(PlaylistCover.preferredURL([(url: "", width: 300), (url: "https://i.scdn.co/only", width: nil)]), "https://i.scdn.co/only")
    }
}
