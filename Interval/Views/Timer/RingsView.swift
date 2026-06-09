import SwiftUI

struct RingsView: View {
    let blockColor: Color
    let blockFraction: CGFloat
    let roundFraction: CGFloat
    let sessionFraction: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Outer ring — session (33% opacity)
            RingTrack(radius: 110, strokeWidth: 1.5)
            Ring(fraction: sessionFraction,
                 radius: 110,
                 strokeWidth: 1.5,
                 color: blockColor.opacity(0.33))

            // Middle ring — round (67% opacity)
            RingTrack(radius: 97, strokeWidth: 2.5)
            Ring(fraction: roundFraction,
                 radius: 97,
                 strokeWidth: 2.5,
                 color: blockColor.opacity(0.67))

            // Inner ring — block (full opacity)
            RingTrack(radius: 82, strokeWidth: 3.5)
            Ring(fraction: blockFraction,
                 radius: 82,
                 strokeWidth: 3.5,
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
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))
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
            .stroke(Color.white.opacity(0.035),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))
            .frame(width: radius * 2, height: radius * 2)
    }
}
