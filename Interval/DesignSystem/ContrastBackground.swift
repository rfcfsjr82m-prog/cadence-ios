import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ContrastBackground
//
// The foundation of the whole look: a full-bleed photograph that is
// *automatically* darkened just enough to keep white text legible. The view
// samples the image's average luminance and adds a black scrim only when the
// image is too bright for the target contrast ratio (defaults to ~4.79:1, i.e.
// WCAG AA for body text). Dark images get no scrim and stay vivid.
//
// Usage:
//   ZStack { content }
//       .background { ContrastBackground(imageName: "bg_dawn") }
//       .preferredColorScheme(.dark)

public struct ContrastBackground: View {
    private let imageName: String
    private let targetRatio: Double

    @State private var overlayOpacity: Double = 0

    public init(imageName: String, targetRatio: Double = 4.79) {
        self.imageName = imageName
        self.targetRatio = targetRatio
    }

    public var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFill()
            DS.Palette.scrim.opacity(overlayOpacity)
        }
        .ignoresSafeArea(.all)
        .onAppear { overlayOpacity = computeOverlay(for: imageName, targetRatio: targetRatio) }
    }

    // MARK: Contrast math

    private func computeOverlay(for imageName: String, targetRatio: Double) -> Double {
        #if canImport(UIKit)
        guard let uiImage = UIImage(named: imageName) else { return 0 }
        let luminance = averageLuminance(of: uiImage)
        // Maximum background luminance that still clears the target ratio for white text.
        let maxAllowed = (1.05 / targetRatio) - 0.05
        guard luminance > maxAllowed else { return 0 }
        let a = 1.0 - (maxAllowed / luminance)
        // Pull back slightly so images stay vivid; cap so we never go fully black.
        return max(0, min(a - 0.30, 0.9))
        #else
        return 0
        #endif
    }

    #if canImport(UIKit)
    /// Downsamples to 20×20 and averages WCAG-relative luminance.
    private func averageLuminance(of image: UIImage) -> Double {
        let dim = 20
        let count = dim * dim
        var pixels = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels, width: dim, height: dim,
            bitsPerComponent: 8, bytesPerRow: dim * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = image.cgImage else { return 0.1 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dim, height: dim))
        var total: Double = 0
        for i in 0..<count {
            let r = Double(pixels[i * 4]) / 255
            let g = Double(pixels[i * 4 + 1]) / 255
            let b = Double(pixels[i * 4 + 2]) / 255
            total += 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        }
        return total / Double(count)
    }

    private func lin(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    #endif
}

// MARK: - Haptics

/// Lightweight haptic feedback for taps and selections. Fire on every
/// meaningful interaction — the product leans on touch feel as much as motion.
public enum Haptics {
    #if canImport(UIKit)
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    #else
    public static func impact(_ style: Int = 0) {}
    public static func selection() {}
    #endif
}
