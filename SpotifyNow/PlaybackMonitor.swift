import AppKit
import Foundation
import os
import SpotifyNowShared
import WidgetKit

private let log = Logger(subsystem: "app.spotifynow", category: "playback")

/// Receives Spotify's playback notification immediately, even if this app is not frontmost.
final class DistributedObserver: NSObject {
    var onChange: (@MainActor () -> Void)?

    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(changed(_:)),
            name: Notification.Name(SpotifyIdentity.playbackNotification),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func changed(_ notification: Notification) {
        Task { @MainActor in
            self.onChange?()
        }
    }
}

@MainActor
@Observable
final class PlaybackMonitor {
    static let shared = PlaybackMonitor()

    private(set) var snapshot = NowPlayingSnapshot(
        updatedAt: .distantPast,
        spotifyRunning: false,
        sourceStatus: .ok,
        playback: nil
    )
    private(set) var artwork: NSImage?
    private(set) var shareOK = false
    private(set) var hasLiveReading = false
    private(set) var lastError: String?

    private var started = false
    private var dirty = true
    private var nextPoll = Date.distantPast
    private var followUpAt = Date.distantFuture
    private var permissionFailures = 0
    private var pending: [PlaybackCommand] = []
    private var handledCommandIDs = Set<UUID>()
    private var artworkJPEG: Data?
    private var artworkURLSeen: String?
    private var artworkToken = 0
    private var artworkInFlightFor: String?
    private var artworkFallbackTried = Set<String>()
    private var loopTask: Task<Void, Never>?
    private var workspaceObservers: [NSObjectProtocol] = []
    private let spotifyEvents = DistributedObserver()

    var isPlaying: Bool { snapshot.playback?.isPlaying == true }

    func start() {
        guard !started else { return }
        started = true
        observe()
        loopTask = Task { @MainActor in
            while !Task.isCancelled {
                let ranCommand = self.drainCommands()
                if ranCommand {
                    self.followUpAt = Date().addingTimeInterval(0.7)
                }
                let now = Date()
                if self.dirty || now >= self.nextPoll {
                    self.dirty = false
                    self.refresh()
                    self.nextPoll = Date().addingTimeInterval(self.pollInterval)
                } else if now >= self.followUpAt {
                    self.followUpAt = .distantFuture
                    self.refresh()
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    func perform(_ command: PlaybackCommand) {
        pending.append(command)
    }

    func retryPermission() {
        permissionFailures = 0
        dirty = true
        nextPoll = .distantPast
    }

    var diagnosticsText: String {
        let playback = snapshot.playback
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return """
        Spotify Now \(version)
        App bundle: \(Bundle.main.bundleIdentifier ?? "unknown")
        Widget bundle: \(EmbeddedWidget.bundleID() ?? "not embedded")
        Entitled groups: \(AppGroupResolver.entitledGroupIdentifiers().joined(separator: ", "))
        Share folders: \(ShareBridge.paths().joined(separator: " | "))
        Sharing: \(shareOK)
        Spotify installed: \(SpotifyProcess.isInstalled)
        Spotify running: \(snapshot.spotifyRunning)
        Status: \(snapshot.sourceStatus.rawValue)
        Track: \(playback?.title ?? "none")
        Artist: \(playback?.artist ?? "none")
        Playing: \(playback?.isPlaying ?? false)
        Last error: \(lastError ?? "none")
        """
    }

    private var pollInterval: TimeInterval {
        switch snapshot.sourceStatus {
        case .spotifyMissing:
            return 30
        case .permissionNeeded:
            return permissionFailures < 4 ? 3 : 30
        case .ok:
            return snapshot.playback?.isPlaying == true ? 4 : 6
        }
    }

    private func observe() {
        spotifyEvents.onChange = { [weak self] in
            self?.dirty = true
        }
        spotifyEvents.start()
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        for name in names {
            let token = NSWorkspace.shared.notificationCenter.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == SpotifyIdentity.bundleID else { return }
                Task { @MainActor in
                    self?.dirty = true
                }
            }
            workspaceObservers.append(token)
        }
    }

    @discardableResult
    private func drainCommands() -> Bool {
        var ran = false
        while !pending.isEmpty {
            run(pending.removeFirst())
            ran = true
        }
        for store in ShareBridge.stores() {
            guard let command = store.readCommand() else { continue }
            if command.shouldExecute(at: Date(), handled: handledCommandIDs) {
                handledCommandIDs.insert(command.id)
                run(command.command)
                ran = true
            }
            store.deleteCommand()
        }
        return ran
    }

    private func run(_ command: PlaybackCommand) {
        let launch = !snapshot.spotifyRunning || snapshot.playback == nil
        let outcome = SpotifyClient.run(SpotifyAppleScript.script(for: command, launchIfNeeded: launch))
        if outcome.isPermissionError {
            permissionFailures += 1
            lastError = outcome.message
            publishPermission()
        } else if let message = outcome.message, outcome.errorNumber != nil {
            lastError = message
            log.error("Spotify command failed: \(message, privacy: .public)")
        } else {
            lastError = nil
        }
        dirty = true
    }

    private func refresh() {
        if !SpotifyProcess.isInstalled {
            publishMissing()
            return
        }
        if !SpotifyProcess.isRunning {
            publishClosed()
            return
        }
        switch SpotifyClient.fetch() {
        case .permissionDenied(let message):
            permissionFailures += 1
            lastError = message
            publishPermission()
        case .notRunning:
            publishClosed()
        case .failed(let message):
            noteFailure(message)
        case .reading(let reading):
            switch reading {
            case .notRunning:
                publishClosed()
            case .stopped:
                publishStopped()
            case .unavailable:
                noteFailure("Spotify didn't answer.")
            case .malformed:
                noteFailure("Couldn't understand Spotify's reply.")
            case .track(let track):
                apply(track)
            }
        }
    }

    private func apply(_ track: ParsedTrack) {
        let now = Date()
        let sameTrack = snapshot.playback?.trackID == track.trackID && !track.trackID.isEmpty
        let keepArt = sameTrack && snapshot.playback?.hasArtwork == true && artworkJPEG != nil
        let playback = Playback(
            trackID: track.trackID,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            position: track.position,
            positionDate: now,
            isPlaying: track.isPlaying,
            hasArtwork: keepArt
        )
        let next = NowPlayingSnapshot(
            updatedAt: now,
            spotifyRunning: true,
            sourceStatus: .ok,
            playback: playback
        )
        permissionFailures = 0
        lastError = nil
        hasLiveReading = true
        publish(next, deleteArtwork: !keepArt)
        if !keepArt {
            fetchArtwork(for: track)
        }
    }

    private func fetchArtwork(for track: ParsedTrack) {
        let trackKey = track.trackID.isEmpty ? track.title : track.trackID
        if artworkInFlightFor == trackKey { return }
        guard let url = track.artworkURL else {
            artworkToken += 1
            fallbackArtwork(trackKey: trackKey, token: artworkToken)
            return
        }
        if url.absoluteString == artworkURLSeen, let artworkJPEG {
            storeArtwork(artworkJPEG)
            return
        }
        artworkInFlightFor = trackKey
        artworkToken += 1
        let token = artworkToken
        Task {
            let jpeg = await ArtworkDownloader.fetchJPEG(from: url)
            guard token == self.artworkToken else { return }
            self.artworkInFlightFor = nil
            if let jpeg {
                self.artworkURLSeen = url.absoluteString
                self.storeArtwork(jpeg)
            } else {
                self.fallbackArtwork(trackKey: trackKey, token: token)
            }
        }
    }

    private func fallbackArtwork(trackKey: String, token: Int) {
        guard token == artworkToken else { return }
        guard artworkFallbackTried.insert(trackKey).inserted else { return }
        guard let raw = SpotifyClient.artworkData(), let jpeg = ImageTranscoder.jpeg(from: raw, maxPixel: 800) else {
            return
        }
        storeArtwork(jpeg)
    }

    private func storeArtwork(_ jpeg: Data) {
        artworkJPEG = jpeg
        guard var playback = snapshot.playback else { return }
        playback.hasArtwork = true
        snapshot.playback = playback
        snapshot.updatedAt = Date()
        publish(snapshot, artwork: jpeg)
    }

    private func publishClosed() {
        guard snapshot.spotifyRunning || snapshot.playback != nil || snapshot.sourceStatus != .ok || !hasLiveReading else {
            var kept = snapshot
            kept.updatedAt = Date()
            kept.spotifyRunning = false
            publish(kept)
            return
        }
        artworkToken += 1
        artworkJPEG = nil
        artworkURLSeen = nil
        hasLiveReading = true
        permissionFailures = 0
        lastError = nil
        publish(
            NowPlayingSnapshot(updatedAt: Date(), spotifyRunning: false, sourceStatus: .ok, playback: nil),
            deleteArtwork: true
        )
    }

    private func publishStopped() {
        artworkToken += 1
        artworkJPEG = nil
        artworkURLSeen = nil
        hasLiveReading = true
        permissionFailures = 0
        lastError = nil
        publish(
            NowPlayingSnapshot(updatedAt: Date(), spotifyRunning: true, sourceStatus: .ok, playback: nil),
            deleteArtwork: true
        )
    }

    private func publishMissing() {
        artworkToken += 1
        artworkJPEG = nil
        hasLiveReading = true
        publish(
            NowPlayingSnapshot(updatedAt: Date(), spotifyRunning: false, sourceStatus: .spotifyMissing, playback: nil),
            deleteArtwork: true
        )
    }

    private func publishPermission() {
        hasLiveReading = true
        publish(
            NowPlayingSnapshot(
                updatedAt: Date(),
                spotifyRunning: SpotifyProcess.isRunning,
                sourceStatus: .permissionNeeded,
                playback: nil
            ),
            deleteArtwork: true
        )
    }

    private func noteFailure(_ message: String) {
        lastError = message
        log.error("\(message, privacy: .public)")
        guard hasLiveReading else { return }
        var kept = snapshot
        kept.updatedAt = Date()
        publish(kept)
    }

    private func publish(_ snapshot: NowPlayingSnapshot, artwork: Data? = nil, deleteArtwork: Bool = false) {
        self.snapshot = snapshot
        if let artwork {
            self.artwork = NSImage(data: artwork)
            artworkJPEG = artwork
        } else if deleteArtwork {
            self.artwork = nil
            artworkJPEG = nil
        }
        var wrote = false
        for store in ShareBridge.stores() {
            do {
                try store.writeSnapshot(snapshot)
                if let artwork {
                    try store.writeArtwork(artwork)
                } else if deleteArtwork || snapshot.playback?.hasArtwork != true {
                    store.deleteArtwork()
                }
                wrote = true
            } catch {
                lastError = error.localizedDescription
                log.error("Couldn't write widget data: \(error.localizedDescription, privacy: .public)")
            }
        }
        shareOK = wrote
        if wrote {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
