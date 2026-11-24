import CoreGraphics
import Foundation
import ImageIO
import SpotifyNowShared
import UniformTypeIdentifiers

enum ImageTranscoder {
    static func jpeg(from data: Data, maxPixel: Int) -> Data? {
        guard data.count < 8_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let longest = max(width, height)
        let scale = longest > maxPixel ? CGFloat(maxPixel) / CGFloat(longest) : 1
        let targetWidth = max(1, Int((CGFloat(width) * scale).rounded()))
        let targetHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return data.count < 2_000_000 ? data : nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaled = context.makeImage() else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.86] as CFDictionary
        CGImageDestinationAddImage(destination, scaled, properties)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

enum ArtworkDownloader {
    static func fetchJPEG(from url: URL) async -> Data? {
        for candidate in ArtworkURL.attempts(for: url) {
            var request = URLRequest(url: candidate, timeoutInterval: 12)
            request.setValue("SpotifyNow/1.0", forHTTPHeaderField: "User-Agent")
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    continue
                }
                if let jpeg = ImageTranscoder.jpeg(from: data, maxPixel: 800) {
                    return jpeg
                }
            } catch {
                continue
            }
        }
        return nil
    }
}
