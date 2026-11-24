import Foundation

public struct SharedStore: Sendable {
    public static let stateFileName = "state.json"
    public static let artworkFileName = "artwork.jpg"
    public static let commandFileName = "command.json"

    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public var stateURL: URL { directory.appendingPathComponent(Self.stateFileName) }
    public var artworkURL: URL { directory.appendingPathComponent(Self.artworkFileName) }
    public var commandURL: URL { directory.appendingPathComponent(Self.commandFileName) }

    public func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func writeSnapshot(_ snapshot: NowPlayingSnapshot) throws {
        guard snapshot.schemaVersion == NowPlayingSnapshot.currentSchema else { return }
        try prepare()
        let data = try NowPlayingSnapshot.makeEncoder().encode(snapshot)
        try data.write(to: stateURL, options: .atomic)
    }

    public func readSnapshot() -> NowPlayingSnapshot? {
        for _ in 0..<2 {
            guard let data = try? Data(contentsOf: stateURL) else { return nil }
            if let snapshot = try? NowPlayingSnapshot.makeDecoder().decode(NowPlayingSnapshot.self, from: data),
               snapshot.schemaVersion == NowPlayingSnapshot.currentSchema {
                return snapshot
            }
        }
        return nil
    }

    public func writeArtwork(_ data: Data) throws {
        guard !data.isEmpty, data.count < 8_000_000 else { return }
        try prepare()
        try data.write(to: artworkURL, options: .atomic)
    }

    public func readArtwork() -> Data? {
        guard let data = try? Data(contentsOf: artworkURL), !data.isEmpty, data.count < 8_000_000 else {
            return nil
        }
        return data
    }

    public func deleteArtwork() {
        try? FileManager.default.removeItem(at: artworkURL)
    }

    public func writeCommand(_ command: CommandEnvelope) throws {
        try prepare()
        let data = try NowPlayingSnapshot.makeEncoder().encode(command)
        try data.write(to: commandURL, options: .atomic)
    }

    public func readCommand() -> CommandEnvelope? {
        guard let data = try? Data(contentsOf: commandURL) else { return nil }
        return try? NowPlayingSnapshot.makeDecoder().decode(CommandEnvelope.self, from: data)
    }

    public func deleteCommand() {
        try? FileManager.default.removeItem(at: commandURL)
    }
}

public enum DirectoryAccess {
    public static func isWritable(_ url: URL, fileManager: FileManager = .default) -> Bool {
        let probe = url.appendingPathComponent(".write-probe")
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
            try Data("ok".utf8).write(to: probe, options: .atomic)
            try fileManager.removeItem(at: probe)
            return true
        } catch {
            return false
        }
    }
}
