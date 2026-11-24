import Foundation

public struct ParsedTrack: Equatable, Sendable {
    public var isPlaying: Bool
    public var trackID: String
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval
    public var position: TimeInterval
    public var artworkURL: URL?

    public init(
        isPlaying: Bool,
        trackID: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        position: TimeInterval,
        artworkURL: URL?
    ) {
        self.isPlaying = isPlaying
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.artworkURL = artworkURL
    }
}

public enum SpotifyScriptReading: Equatable, Sendable {
    case notRunning
    case stopped
    case unavailable
    /// Spotify answered, but the reply was not a track record we understand.
    case malformed
    case track(ParsedTrack)
}

public enum SpotifyScriptCodec {
    /// Field separator. Unlikely in titles, and stripped again inside the script.
    public static let delimiter = "|||"

    public static func parse(_ output: String) -> SpotifyScriptReading {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .malformed }
        let parts = trimmed.components(separatedBy: delimiter).map(cleanField)
        let status = parts[0].lowercased()
        switch status {
        case "not_running":
            return .notRunning
        case "stopped":
            return .stopped
        case "unavailable":
            return .unavailable
        case "playing", "paused":
            guard parts.count == 8 else { return .malformed }
            guard let durationMs = parseWholeNumber(parts[5]), let positionMs = parseWholeNumber(parts[6]) else {
                return .malformed
            }
            let duration = max(0, durationMs / 1000)
            let rawPosition = max(0, positionMs / 1000)
            let position = duration > 0 ? min(rawPosition, duration) : rawPosition
            let track = ParsedTrack(
                isPlaying: status == "playing",
                trackID: parts[1],
                title: parts[2],
                artist: parts[3],
                album: parts[4],
                duration: duration,
                position: position,
                artworkURL: sanitizedArtworkURL(parts[7])
            )
            return .track(track)
        default:
            return .malformed
        }
    }

    /// Integers from AppleScript. Accepts a trailing ".0" and thousands separators.
    static func parseWholeNumber(_ raw: String) -> Double? {
        let compact = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
        guard !compact.isEmpty else { return nil }
        let groups = compact.split(whereSeparator: { $0 == "." || $0 == "," }).map(String.init)
        guard let head = groups.first, head.allSatisfy(\.isNumber), !head.isEmpty else { return nil }
        let normalized: String
        if groups.count > 1, groups.dropFirst().allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isNumber) }) {
            normalized = groups.joined()
        } else if groups.count == 2, groups[1].allSatisfy({ $0 == "0" }) {
            normalized = head
        } else if groups.count == 1 {
            normalized = head
        } else {
            return nil
        }
        return Double(normalized)
    }

    public static func sanitizedArtworkURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "missing value", let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        guard let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func cleanField(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "\r\n", with: " ")
        text = text.replacingOccurrences(of: "\n", with: " ")
        text = text.replacingOccurrences(of: "\r", with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text == "missing value" { return "" }
        return text
    }
}

public enum ArtworkURL {
    /// Prefer https. Keep the original http URL as a fallback when ATS allows it.
    public static func attempts(for url: URL) -> [URL] {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return [] }
        if scheme == "http", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            parts.scheme = "https"
            if let https = parts.url, https.absoluteString != url.absoluteString {
                return [https, url]
            }
        }
        return [url]
    }
}

public enum SpotifyAppleScript {
    public static let play = "tell application \"Spotify\" to play"
    public static let playPause = "tell application \"Spotify\" to playpause"
    public static let nextTrack = "tell application \"Spotify\" to next track"
    public static let previousTrack = "tell application \"Spotify\" to previous track"
    public static let fetchArtwork = """
    tell application "Spotify"
      try
        return artwork of current track
      on error
        return ""
      end try
    end tell
    """

    /// One Apple Event. Duration and position are whole milliseconds so the
    /// reply does not depend on the decimal separator.
    public static let fetchNowPlaying: String = {
        let d = SpotifyScriptCodec.delimiter
        return """
        on sanitize(value)
          set d to "\(d)"
          set t to ""
          try
            set t to value as string
          on error
            set AppleScript's text item delimiters to ""
            return ""
          end try
          if t is "missing value" then
            set AppleScript's text item delimiters to ""
            return ""
          end if
          set AppleScript's text item delimiters to d
          set parts to text items of t
          set AppleScript's text item delimiters to ""
          set t to parts as text
          set AppleScript's text item delimiters to linefeed
          set parts to text items of t
          set AppleScript's text item delimiters to " "
          set t to parts as text
          set AppleScript's text item delimiters to return
          set parts to text items of t
          set AppleScript's text item delimiters to " "
          set t to parts as text
          set AppleScript's text item delimiters to ""
          return t
        end sanitize

        if application "Spotify" is not running then
          return "not_running"
        end if

        set pState to "unavailable"
        set tName to ""
        set tArtist to ""
        set tAlbum to ""
        set tID to ""
        set tDur to 0
        set tPos to 0
        set tArt to ""

        tell application "Spotify"
          try
            if player state is playing then
              set pState to "playing"
            else if player state is paused then
              set pState to "paused"
            else
              set pState to "stopped"
            end if
          on error
            return "unavailable"
          end try
          if pState is "stopped" then
            return "stopped"
          end if
          try
            set tName to name of current track
          on error
            return "stopped"
          end try
          try
            set tArtist to artist of current track
          end try
          try
            set tAlbum to album of current track
          end try
          try
            set tID to id of current track
          end try
          try
            set tDur to duration of current track
          end try
          try
            set tPos to player position
          end try
          try
            set tArt to artwork url of current track
          end try
        end tell

        set tDurText to (tDur as integer) as string
        set tPosMs to round (tPos * 1000) rounding toward zero
        set tPosText to (tPosMs as integer) as string
        set d to "\(d)"
        return my sanitize(pState) & d & my sanitize(tID) & d & my sanitize(tName) & d & my sanitize(tArtist) & d & my sanitize(tAlbum) & d & my sanitize(tDurText) & d & my sanitize(tPosText) & d & my sanitize(tArt)
        """
    }()

    public static func script(for command: PlaybackCommand, launchIfNeeded: Bool) -> String {
        switch command {
        case .next:
            return nextTrack
        case .previous:
            return previousTrack
        case .playPause:
            return launchIfNeeded ? play : playPause
        }
    }
}
