import AppKit
import Foundation

@MainActor
@Observable
final class PlaylistArtwork {
    static let shared = PlaylistArtwork()

    private(set) var images: [String: NSImage] = [:]
    private var loading: Set<String> = []

    func image(for id: String) -> NSImage? {
        images[id]
    }

    func load(id: String, urlString: String?) async {
        guard let urlString, !urlString.isEmpty, images[id] == nil, !loading.contains(id) else { return }
        loading.insert(id)
        defer { loading.remove(id) }
        if let cached = readDisk(id: id) {
            images[id] = cached
            return
        }
        guard let url = URL(string: urlString) else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return }
            guard let image = NSImage(data: data) else { return }
            images[id] = image
            writeDisk(id: id, data: data)
        } catch {
            return
        }
    }

    private func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("SpotifyNow/PlaylistCovers", isDirectory: true)
    }

    private func file(id: String) -> URL {
        let safe = id.filter { $0.isLetter || $0.isNumber }
        return directory().appendingPathComponent("\(safe).img")
    }

    private func readDisk(id: String) -> NSImage? {
        guard let data = try? Data(contentsOf: file(id: id)) else { return nil }
        return NSImage(data: data)
    }

    private func writeDisk(id: String, data: Data) {
        let folder = directory()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file(id: id), options: .atomic)
    }
}
