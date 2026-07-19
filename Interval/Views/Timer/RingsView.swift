import SwiftUI

struct RingsView: View {
    let blockColor: Color
    let blockFraction: CGFloat
    let roundFraction: CGFloat
    let sessionFraction: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Bold rings matching the share-card look: equal stroke widths,
    // rounded caps, and a visible background track.
    private static let strokeWidth: CGFloat = 10
    private static let gap: CGFloat = 6.5   // strokeWidth * 0.65, like ShareRingsView

    var body: some View {
        let w = Self.strokeWidth
        let step = w + Self.gap
        ZStack {
            // Outer ring — session (33% opacity)
            RingTrack(radius: 110, strokeWidth: w)
            Ring(fraction: sessionFraction,
                 radius: 110,
                 strokeWidth: w,
                 color: blockColor.opacity(0.33))

            // Middle ring — round (67% opacity)
            RingTrack(radius: 110 - step, strokeWidth: w)
            Ring(fraction: roundFraction,
                 radius: 110 - step,
                 strokeWidth: w,
                 color: blockColor.opacity(0.67))

            // Inner ring — block (full opacity)
            RingTrack(radius: 110 - step * 2, strokeWidth: w)
            Ring(fraction: blockFraction,
                 radius: 110 - step * 2,
                 strokeWidth: w,
                 color: blockColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Session \(Int(sessionFraction * 100))% complete")
    }
}

// MARK: - Ring shape (draining: 1.0 = full, 0.0 = empty)

private struct Ring: View {
    let fraction: CGFloat
    let radius: CGFloat
    let strokeWidth: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .trim(from: 0, to: max(0, min(1, fraction)))
            .stroke(color,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
            .rotationEffect(.degrees(-90))
    }
}

// MARK: - Background track ring

private struct RingTrack: View {
    let radius: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(0.07),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
            .frame(width: radius * 2, height: radius * 2)
    }
}
