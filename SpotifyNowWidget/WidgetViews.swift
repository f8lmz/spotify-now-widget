import AppIntents
import SpotifyNowShared
import SwiftUI
import WidgetKit

struct SpotifyNowWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: NowPlayingEntry

    private var presentation: WidgetPresentation { entry.presentation }

    var body: some View {
        Group {
            if family == .systemSmall, let url = presentation.spotifyURL {
                layout.widgetURL(url)
            } else {
                layout
            }
        }
        .containerBackground(for: .widget) { backdrop }
    }

    @ViewBuilder
    private var layout: some View {
        switch family {
        case .systemSmall:
            small
        case .systemLarge:
            large
        default:
            medium
        }
    }

    private var small: some View {
        ZStack(alignment: .topTrailing) {
            if presentation.phase == .track {
                VStack(alignment: .leading, spacing: 3) {
                    Spacer(minLength: 0)
                    Text(titleText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryInk)
                        .lineLimit(2)
                    if !presentation.artist.isEmpty {
                        Text(presentation.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(secondaryInk)
                            .lineLimit(1)
                    }
                    if let fraction = presentation.fraction {
                        PlaybackBar(fraction: fraction, tint: barTint, track: barTrack, height: 3)
                            .padding(.top, 6)
                    }
                }
                if lightOnArt {
                    stateBadge
                }
            } else {
                emptyState
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            if presentation.phase == .track {
                HStack(alignment: .center, spacing: 12) {
                    artwork(side: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.headline)
                            .foregroundStyle(primaryInk)
                            .lineLimit(1)
                        if !presentation.artist.isEmpty {
                            Text(presentation.artist)
                                .font(.subheadline)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(1)
                        }
                        if !presentation.album.isEmpty {
                            Text(presentation.album)
                                .font(.caption)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                progressRow
            } else {
                emptyState
            }
            if showsTransport {
                transport
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 14) {
            if presentation.phase == .track {
                HStack(alignment: .top, spacing: 16) {
                    artwork(side: 132)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleText)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(primaryInk)
                            .lineLimit(2)
                        if !presentation.artist.isEmpty {
                            Text(presentation.artist)
                                .font(.title3)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(1)
                        }
                        if !presentation.album.isEmpty {
                            Text(presentation.album)
                                .font(.body)
                                .foregroundStyle(secondaryInk)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Text(presentation.isPlaying ? "Playing in Spotify" : "Paused in Spotify")
                            .font(.caption)
                            .foregroundStyle(secondaryInk)
                    }
                    Spacer(minLength: 0)
                }
                progressRow
            } else {
                emptyState
            }
            if showsTransport {
                transport
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var progressRow: some View {
        HStack(spacing: 8) {
            Text(formatPlaybackTime(presentation.position))
                .frame(minWidth: 36, alignment: .leading)
            if let fraction = presentation.fraction {
                PlaybackBar(fraction: fraction, tint: barTint, track: barTrack)
            } else {
                PlaybackBar(fraction: 0, tint: barTint, track: barTrack)
            }
            Text(formatPlaybackTime(presentation.duration))
                .frame(minWidth: 36, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .foregroundStyle(secondaryInk)
    }

    private var transport: some View {
        HStack(spacing: 22) {
            Spacer(minLength: 0)
            TransportButton(intent: PreviousTrackIntent(), symbol: "backward.fill", label: "Previous")
            TransportButton(
                intent: PlayPauseIntent(),
                symbol: presentation.isPlaying ? "pause.fill" : "play.fill",
                label: presentation.isPlaying ? "Pause" : "Play",
                prominent: renderingMode != .accented
            )
            TransportButton(intent: NextTrackIntent(), symbol: "forward.fill", label: "Next")
            Spacer(minLength: 0)
        }
    }

    private var emptyState: some View {
        let copy = emptyCopy
        return VStack(spacing: 8) {
            Image(systemName: copy.symbol)
                .font(.system(size: family == .systemLarge ? 26 : 20, weight: .semibold))
                .foregroundStyle(renderingMode == .accented ? Color.primary : Color.nowGreen)
                .frame(width: 44, height: 44)
                .background(Color.nowGreen.opacity(lightOnArt ? 0.22 : 0.14), in: Circle())
            Text(copy.title)
                .font(.headline)
                .foregroundStyle(primaryInk)
                .multilineTextAlignment(.center)
            Text(copy.subtitle)
                .font(.caption)
                .foregroundStyle(secondaryInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stateBadge: some View {
        Image(systemName: presentation.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .padding(6)
            .background(.black.opacity(0.38), in: Circle())
            .accessibilityLabel(presentation.isPlaying ? "Playing" : "Paused")
    }

    private func artwork(side: CGFloat) -> some View {
        let radius: CGFloat = side > 100 ? 16 : 10
        return artworkImage
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var artworkImage: some View {
        if let image = entry.artwork {
            if #available(macOS 15, *) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
        } else {
            CoverGradient(seed: presentation.coverSeed)
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if family == .systemSmall && renderingMode != .accented {
            ZStack {
                if let image = entry.artwork {
                    if #available(macOS 15, *) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .widgetAccentedRenderingMode(.fullColor)
                            .scaledToFill()
                    } else {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFill()
                    }
                } else {
                    CoverGradient(seed: presentation.coverSeed)
                }
                LinearGradient(
                    colors: [.black.opacity(0.02), .black.opacity(0.12), .black.opacity(0.78)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        } else {
            Rectangle().fill(.background)
        }
    }

    private var showsTransport: Bool {
        guard family != .systemSmall else { return false }
        switch presentation.phase {
        case .track, .nothingPlaying, .spotifyClosed:
            return true
        default:
            return false
        }
    }

    private var lightOnArt: Bool {
        family == .systemSmall && renderingMode != .accented
    }

    private var primaryInk: Color { lightOnArt ? .white : .primary }
    private var secondaryInk: Color { lightOnArt ? .white.opacity(0.78) : .secondary }
    private var barTint: Color { renderingMode == .accented ? .primary : .nowGreen }
    private var barTrack: Color { lightOnArt ? .white.opacity(0.28) : .primary.opacity(0.14) }

    private var titleText: String {
        presentation.title.isEmpty ? "Unknown title" : presentation.title
    }

    private var emptyCopy: (symbol: String, title: String, subtitle: String) {
        switch presentation.phase {
        case .waitingForApp:
            return ("hourglass", "Connecting", "Keep Spotify Now running in the menu bar.")
        case .appNotRunning:
            return ("music.note", "Spotify Now isn’t running", "Open it, then play a song in Spotify.")
        case .permissionNeeded:
            return ("lock.fill", "Permission needed", "Allow Spotify Now to control Spotify.")
        case .spotifyMissing:
            return ("arrow.down.app", "Spotify isn’t installed", "Install the Spotify desktop app.")
        case .spotifyClosed:
            return ("play.circle", "Spotify isn’t open", "Open Spotify and press play.")
        case .nothingPlaying:
            return ("pause.circle", "Nothing playing", "Press play in Spotify.")
        case .track:
            return ("music.note", "Spotify", "")
        }
    }
}

private struct TransportButton<I: AppIntent>: View {
    var intent: I
    var symbol: String
    var label: String
    var prominent = false

    var body: some View {
        Button(intent: intent) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 15 : 13, weight: .bold))
                .foregroundStyle(prominent ? Color.white : Color.primary)
                .frame(width: prominent ? 36 : 32, height: prominent ? 36 : 32)
                .background {
                    if prominent {
                        Circle().fill(Color.nowGreen)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview(as: .systemSmall) {
    SpotifyNowWidget()
} timeline: {
    NowPlayingEntry(date: .now, presentation: .placeholder(), artwork: nil)
}

#Preview(as: .systemMedium) {
    SpotifyNowWidget()
} timeline: {
    NowPlayingEntry(date: .now, presentation: .placeholder(), artwork: nil)
    NowPlayingEntry(
        date: .now.addingTimeInterval(60),
        presentation: WidgetPresentationBuilder.make(snapshot: nil, at: .now),
        artwork: nil
    )
}

#Preview(as: .systemLarge) {
    SpotifyNowWidget()
} timeline: {
    NowPlayingEntry(date: .now, presentation: .placeholder(), artwork: nil)
}
