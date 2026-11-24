import AppIntents
import CoreGraphics
import ImageIO
import SpotifyNowShared
import SwiftUI
import WidgetKit

struct NowPlayingEntry: TimelineEntry {
    var date: Date
    var presentation: WidgetPresentation
    var artwork: CGImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NowPlayingEntry {
        NowPlayingEntry(date: Date(), presentation: .placeholder(), artwork: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NowPlayingEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        completion(WidgetBridge.entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NowPlayingEntry>) -> Void) {
        let now = Date()
        let loaded = WidgetBridge.load()
        let plan = TimelinePlanner.plan(snapshot: loaded.snapshot, now: now)
        let entries = plan.entries.map { point in
            NowPlayingEntry(date: point.date, presentation: point.presentation, artwork: loaded.artwork)
        }
        let timeline = Timeline(entries: entries, policy: .after(plan.reloadAfter))
        completion(timeline)
    }
}

@main
struct SpotifyNowWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpotifyNowWidget()
    }
}

struct SpotifyNowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SpotifyNowWidgetKind.nowPlaying, provider: Provider()) { entry in
            SpotifyNowWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Spotify Now")
        .description("Album art, track, and playback controls for the Spotify app on this Mac.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

enum ArtworkImage {
    static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

enum WidgetBridge {
    static func entry(at date: Date) -> NowPlayingEntry {
        let loaded = load()
        return NowPlayingEntry(
            date: date,
            presentation: WidgetPresentationBuilder.make(snapshot: loaded.snapshot, at: date),
            artwork: loaded.artwork
        )
    }

    static func load() -> (snapshot: NowPlayingSnapshot?, artwork: CGImage?) {
        var best: (NowPlayingSnapshot, SharedStore)?
        for store in directories() {
            guard let snapshot = store.readSnapshot() else { continue }
            if best == nil || snapshot.updatedAt > best!.0.updatedAt {
                best = (snapshot, store)
            }
        }
        guard let best else { return (nil, nil) }
        var image: CGImage?
        if best.0.playback?.hasArtwork == true, let data = best.1.readArtwork() {
            image = ArtworkImage.decode(data)
        }
        return (best.0, image)
    }

    static func send(_ command: PlaybackCommand) {
        let envelope = CommandEnvelope(id: UUID(), command: command, createdAt: Date())
        for store in directories() {
            try? store.writeCommand(envelope)
        }
    }

    private static func directories() -> [SharedStore] {
        var urls: [URL] = []
        if let group = AppGroupResolver.writableStoreURL() {
            urls.append(group)
        }
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let directory = SharedLocation.storeDirectory(in: support)
            if DirectoryAccess.isWritable(directory) {
                urls.append(directory)
            }
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.path).inserted }.map(SharedStore.init(directory:))
    }
}
