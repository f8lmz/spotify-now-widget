#if canImport(SwiftUI)
import SwiftUI

public extension Color {
    static let nowGreen = Color(red: 29.0 / 255.0, green: 185.0 / 255.0, blue: 84.0 / 255.0)
}

public struct CoverGradient: View {
    public var seed: String

    public init(seed: String) {
        self.seed = seed
    }

    public var body: some View {
        let hue = CoverHueMaker.hues(for: seed)
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: hue.primary, saturation: 0.48, brightness: 0.42),
                    Color(hue: hue.secondary, saturation: 0.55, brightness: 0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 140, height: 140)
                .offset(x: 56, y: -64)
        }
    }
}

public struct PlaybackBar: View {
    public var fraction: Double
    public var tint: Color
    public var track: Color
    public var height: CGFloat

    public init(fraction: Double, tint: Color, track: Color, height: CGFloat = 4) {
        self.fraction = min(1, max(0, fraction))
        self.tint = tint
        self.track = track
        self.height = height
    }

    public var body: some View {
        Capsule()
            .fill(track)
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .clipShape(Capsule())
            .accessibilityElement()
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }
}
#endif
