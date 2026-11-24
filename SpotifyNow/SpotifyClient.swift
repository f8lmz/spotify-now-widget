import AppKit
import Foundation
import SpotifyNowShared

struct ScriptOutcome {
    var output: String?
    var errorNumber: Int?
    var message: String?
    var imageData: Data?

    var isPermissionError: Bool {
        if errorNumber == -1743 { return true }
        let text = (message ?? "").lowercased()
        return text.contains("not authorized to send apple events")
    }

    var isNotRunning: Bool {
        errorNumber == -600
    }
}

enum FetchResult {
    case permissionDenied(String)
    case notRunning
    case failed(String)
    case reading(SpotifyScriptReading)
}

@MainActor
enum SpotifyClient {
    static func fetch() -> FetchResult {
        let outcome = run(SpotifyAppleScript.fetchNowPlaying)
        if outcome.isPermissionError {
            return .permissionDenied(outcome.message ?? "Not allowed to control Spotify.")
        }
        if outcome.isNotRunning {
            return .notRunning
        }
        if let output = outcome.output, !output.isEmpty {
            let reading = SpotifyScriptCodec.parse(output)
            if case .malformed = reading {
                return .failed(outcome.message ?? "Couldn't understand Spotify's reply.")
            }
            return .reading(reading)
        }
        return .failed(outcome.message ?? "Couldn't read Spotify.")
    }

    static func artworkData() -> Data? {
        run(SpotifyAppleScript.fetchArtwork).imageData
    }

    static func run(_ source: String) -> ScriptOutcome {
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return ScriptOutcome(message: "Couldn't prepare the Spotify script.")
        }
        // The SDK types this as non-optional, but a failed script returns nil at
        // runtime. Read the descriptor only when AppleScript did not report an error.
        let descriptor = script.executeAndReturnError(&errorInfo)
        var outcome = ScriptOutcome()
        if let errorInfo {
            outcome.errorNumber = errorNumber(from: errorInfo)
            outcome.message = errorInfo[NSAppleScript.errorMessage] as? String
            return outcome
        }
        outcome.output = descriptor.stringValue
        outcome.imageData = imagePayload(from: descriptor)
        return outcome
    }

    private static func errorNumber(from info: NSDictionary) -> Int? {
        let value = info[NSAppleScript.errorNumber]
        if let number = value as? NSNumber { return number.intValue }
        if let number = value as? Int { return number }
        return nil
    }

    private static func imagePayload(from descriptor: NSAppleEventDescriptor) -> Data? {
        if let text = descriptor.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           text.isEmpty || text == "missing value" {
            return nil
        }
        let types: [DescType] = [
            DescType(0x54494646), // TIFF
            DescType(0x4A504547), // JPEG
            DescType(0x504E4766), // PNGf
            DescType(0x74647461), // tdta
        ]
        for type in types {
            guard let coerced = descriptor.coerce(toDescriptorType: type) else { continue }
            if coerced.data.count > 32 {
                return coerced.data
            }
        }
        if descriptor.data.count > 32, descriptor.stringValue == nil {
            return descriptor.data
        }
        return nil
    }
}
