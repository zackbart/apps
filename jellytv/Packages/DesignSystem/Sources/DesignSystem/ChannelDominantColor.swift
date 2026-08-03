import SwiftUI
import Nuke

#if os(tvOS) || os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

/// Extracts a "dominant" color from a channel logo for use as the splash
/// background gradient. Uses an HSL histogram (24 hue buckets × 15°) weighted
/// by saturation ≥ 0.4 and luminance in [0.2, 0.8] — a simple `CIAreaAverage`
/// produces gray for white-on-transparent logos (the common case for broadcast
/// channels), so we explicitly throw out neutral pixels.
///
/// Cached in-memory keyed on URL string. Cache hits are synchronous on
/// `Task.value` reuse via `actor`-isolated state. Misses fetch from Nuke's
/// memory cache first (already-loaded logo → near-instant), falling back to
/// network fetch via `ImagePipeline.shared`.
public actor ChannelDominantColor {
    public static let shared = ChannelDominantColor()

    private var cache: [String: Color?] = [:]

    private init() {}

    /// Returns a dominant color for the given logo URL, or `nil` if no
    /// qualifying pixel was found (e.g., logo is purely white-on-transparent).
    /// Callers should fall back to a neutral background when nil.
    public func extract(logoURL: URL?) async -> Color? {
        guard let logoURL else { return nil }
        let key = logoURL.absoluteString
        if let cached = cache[key] { return cached }

        let image = await loadImage(from: logoURL)
        let color = image.flatMap { Self.dominantColor(from: $0) }
        cache[key] = color
        return color
    }

    private func loadImage(from url: URL) async -> PlatformImage? {
        let request = ImageRequest(url: url)
        if let cached = ImagePipeline.shared.cache.cachedImage(for: request) {
            return cached.image
        }
        do {
            let response = try await ImagePipeline.shared.image(for: request)
            return response
        } catch {
            return nil
        }
    }

    // MARK: - Color analysis

    /// Downscale, iterate pixels, build a 24-bucket hue histogram weighted by
    /// saturation × (1 if luminance is in [0.2, 0.8] else 0). Returns the
    /// representative color of the most-weighted bucket.
    nonisolated static func dominantColor(from image: PlatformImage) -> Color? {
        guard let cgImage = cgImage(from: image) else { return nil }
        let width = 64
        let height = 64

        // Render into a fixed-size RGBA8 bitmap so iteration is uniform.
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let context = pixels.withUnsafeMutableBytes({ ptr -> CGContext? in
            CGContext(
                data: ptr.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 24 hue buckets at 15° each.
        let bucketCount = 24
        var weights = [Double](repeating: 0, count: bucketCount)
        var hueAccumR = [Double](repeating: 0, count: bucketCount)
        var hueAccumG = [Double](repeating: 0, count: bucketCount)
        var hueAccumB = [Double](repeating: 0, count: bucketCount)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Double(pixels[offset]) / 255.0
                let g = Double(pixels[offset + 1]) / 255.0
                let b = Double(pixels[offset + 2]) / 255.0
                let a = Double(pixels[offset + 3]) / 255.0
                if a < 0.5 { continue } // skip transparent / nearly-transparent

                let (h, s, l) = rgbToHSL(r: r, g: g, b: b)
                guard s >= 0.4, l >= 0.2, l <= 0.8 else { continue }

                let bucket = min(Int(h * Double(bucketCount)), bucketCount - 1)
                let weight = s * a
                weights[bucket] += weight
                hueAccumR[bucket] += r * weight
                hueAccumG[bucket] += g * weight
                hueAccumB[bucket] += b * weight
            }
        }

        guard let bestBucket = weights.indices.max(by: { weights[$0] < weights[$1] }),
              weights[bestBucket] > 0 else {
            return nil
        }
        let totalWeight = weights[bestBucket]
        let r = hueAccumR[bestBucket] / totalWeight
        let g = hueAccumG[bestBucket] / totalWeight
        let b = hueAccumB[bestBucket] / totalWeight
        return Color(red: r, green: g, blue: b)
    }

    nonisolated private static func cgImage(from image: PlatformImage) -> CGImage? {
        #if os(tvOS) || os(iOS)
        return image.cgImage
        #else
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #endif
    }

    /// Returns hue (0–1, where 0=red), saturation (0–1), luminance (0–1).
    nonisolated private static func rgbToHSL(r: Double, g: Double, b: Double) -> (h: Double, s: Double, l: Double) {
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let l = (maxC + minC) / 2.0
        guard maxC != minC else { return (0, 0, l) }
        let d = maxC - minC
        let s = l > 0.5 ? d / (2.0 - maxC - minC) : d / (maxC + minC)
        var h: Double
        if maxC == r {
            h = (g - b) / d + (g < b ? 6 : 0)
        } else if maxC == g {
            h = (b - r) / d + 2
        } else {
            h = (r - g) / d + 4
        }
        h /= 6.0
        return (h, s, l)
    }
}
