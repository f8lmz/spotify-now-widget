import XCTest
@testable import SpotifyNowShared

final class StoreAndIdentityTests: XCTestCase {
    func testSnapshotAndCommandRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SharedStore(directory: directory)
        let now = Date(timeIntervalSince1970: 1_700_000_000.125)
        let snapshot = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: Playback(
                trackID: "spotify:track:abc",
                title: "Night Drive",
                artist: "Silver Line",
                album: "Coastal",
                duration: 200,
                position: 12,
                positionDate: now,
                isPlaying: true,
                hasArtwork: true
            )
        )
        try store.writeSnapshot(snapshot)
        let read = try XCTUnwrap(store.readSnapshot())
        XCTAssertEqual(read.playback?.title, "Night Drive")
        XCTAssertEqual(read.updatedAt.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(read.sourceStatus, .ok)

        let command = CommandEnvelope(id: UUID(), command: .next, createdAt: now)
        try store.writeCommand(command)
        XCTAssertEqual(try XCTUnwrap(store.readCommand()), command)
        store.deleteCommand()
        XCTAssertNil(store.readCommand())

        try store.writeArtwork(Data([0xFF, 0xD8, 0xFF, 0xD9]))
        XCTAssertEqual(store.readArtwork(), Data([0xFF, 0xD8, 0xFF, 0xD9]))
        store.deleteArtwork()
        XCTAssertNil(store.readArtwork())
    }

    func testDirectoryAccessAndWidgetContainerDetection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("store", isDirectory: true)
        XCTAssertTrue(DirectoryAccess.isWritable(folder))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".write-probe").path))

        let home = root.appendingPathComponent("home", isDirectory: true)
        let bundle = "app.spotifynow.TESTTEAM12.widget"
        XCTAssertFalse(SharedLocation.widgetContainerIsReady(home: home, widgetBundleID: bundle, fileExists: { _ in false }))
        let metadata = home
            .appendingPathComponent("Library/Containers/\(bundle)/.com.apple.containermanagerd.metadata.plist")
        XCTAssertTrue(SharedLocation.widgetContainerIsReady(home: home, widgetBundleID: bundle, fileExists: { $0.path == metadata.path }))
        let support = SharedLocation.widgetApplicationSupport(home: home, widgetBundleID: bundle)
        XCTAssertTrue(support.path.contains("/Containers/\(bundle)/Data/Library/Application Support"))
        let store = SharedLocation.storeDirectory(in: support)
        XCTAssertTrue(store.lastPathComponent == SharedLocation.folderName)
    }

    func testTeamIDAndGroupCandidates() {
        XCTAssertEqual(AppGroupResolver.teamID(fromApplicationIdentifier: "AB12CD34EF.app.spotifynow.AB12CD34EF"), "AB12CD34EF")
        XCTAssertNil(AppGroupResolver.teamID(fromApplicationIdentifier: "app.spotifynow"))
        XCTAssertNil(AppGroupResolver.teamID(fromApplicationIdentifier: "TOO-SHORT.app"))
        XCTAssertEqual(AppGroupResolver.groupIdentifier(teamID: "AB12CD34EF"), "AB12CD34EF.app.spotifynow")
        XCTAssertTrue(AppGroupResolver.isUsableGroupIdentifier("AB12CD34EF.app.spotifynow"))
        XCTAssertFalse(AppGroupResolver.isUsableGroupIdentifier("$(TeamIdentifierPrefix)app.spotifynow"))
        XCTAssertFalse(AppGroupResolver.isUsableGroupIdentifier("group.app.spotifynow"))
        XCTAssertEqual(AppGroupResolver.groupSuffix, "app.spotifynow")

        let ids = AppGroupResolver.candidateGroupIdentifiers(
            entitlementGroups: [" AB12CD34EF.app.spotifynow ", "AB12CD34EF.app.spotifynow"],
            applicationIdentifier: "AB12CD34EF.app.spotifynow.AB12CD34EF"
        )
        XCTAssertEqual(ids, ["AB12CD34EF.app.spotifynow"])
    }

    func testCommandAge() {
        let now = Date(timeIntervalSince1970: 50_000)
        let fresh = CommandEnvelope(id: UUID(), command: .playPause, createdAt: now.addingTimeInterval(-2))
        let old = CommandEnvelope(id: UUID(), command: .next, createdAt: now.addingTimeInterval(-20))
        XCTAssertTrue(fresh.shouldExecute(at: now, handled: []))
        XCTAssertFalse(fresh.shouldExecute(at: now, handled: [fresh.id]))
        XCTAssertFalse(old.shouldExecute(at: now, handled: []))
    }

    func testSpotifyLink() {
        let now = Date()
        let snapshot = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: Playback(
                trackID: "spotify:track:abc",
                title: "Night Drive",
                artist: "Silver Line",
                album: "Coastal",
                duration: 100,
                position: 25,
                positionDate: now,
                isPlaying: true,
                hasArtwork: false
            )
        )
        let presentation = WidgetPresentationBuilder.make(snapshot: snapshot, at: now)
        XCTAssertEqual(presentation.spotifyURL?.absoluteString, "spotify:track:abc")
        XCTAssertEqual(presentation.fraction ?? 0, 0.25, accuracy: 0.0001)
        XCTAssertEqual(SpotifyNowWidgetKind.nowPlaying, "SpotifyNow")
        XCTAssertEqual(SpotifyIdentity.bundleID, "com.spotify.client")
    }
}
