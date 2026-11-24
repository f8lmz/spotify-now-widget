import AppIntents
import SpotifyNowShared

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var description = IntentDescription("Play or pause the Spotify app on this Mac.")
        static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.send(.playPause)
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skip to the next track in the Spotify app on this Mac.")
        static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.send(.next)
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Go to the previous track in the Spotify app on this Mac.")
        static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetBridge.send(.previous)
        return .result()
    }
}
