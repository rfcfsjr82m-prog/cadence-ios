import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Cadence Live Activity Widget
//
// Renders the lock-screen and Dynamic Island Live Activity for an active
// Cadence timer session.  The main app starts/updates/ends the Activity;
// this extension only provides the views.

@main
struct CadenceWidgetBundle: WidgetBundle {
    var body: some Widget {
        CadenceLiveActivityWidget()
        PinnedTimersWidget()
    }
}

// MARK: - Widget

struct CadenceLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CadenceActivityAttributes.self) { context in
            // ── Lock Screen / Notification banner ─────────────────────────────
            LockScreenLiveActivityView(
                attributes: context.attributes,
                state: context.state
            )
            .activityBackgroundTint(Color(hex: "111116"))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            // ── Dynamic Island ────────────────────────────────────────────────
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.timerName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(context.state.blockLabel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.roundLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.55))
                        Text(formatTime(context.state.blockLeft))
                            .font(.system(size: 22, design: .monospaced).weight(.thin))
                            .foregroundStyle(.white)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressBar(
                        fraction: blockFraction(state: context.state),
                        color: Color(hex: context.state.blockColorHex)
                    )
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: context.state.blockColorHex))
            } compactTrailing: {
                Text(formatTime(context.state.blockLeft))
                    .font(.system(size: 13, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            } minimal: {
                Text(formatTime(context.state.blockLeft))
                    .font(.system(size: 11, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color(hex: context.state.blockColorHex))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let attributes: CadenceActivityAttributes
    let state: CadenceActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // Colour accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: state.blockColorHex))
                .frame(width: 4)

            // Block info
            VStack(alignment: .leading, spacing: 3) {
                Text(attributes.timerName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.50))
                Text(state.blockLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(state.roundLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            // Time remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatTime(state.blockLeft))
                    .font(.system(size: 32, design: .monospaced).weight(.thin))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if state.isPaused {
                    Text("Paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    Text(formatTime(state.totalLeft) + " total")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Progress bar

private struct ProgressBar: View {
    let fraction: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * fraction))
            }
        }
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: Int) -> String {
    let s = max(0, seconds)
    let m = s / 60; let sec = s % 60
    return String(format: "%d:%02d", m, sec)
}

private func blockFraction(state: CadenceActivityAttributes.ContentState) -> CGFloat {
    // We don't store block duration in state, so use totalLeft / session as approximation
    // The main ring uses blockLeft which resets each block — just show blockLeft visually
    // as a 0-1 progress by treating each full minute as 100%
    let secs = max(1, state.blockLeft)
    // Normalise to nearest 5-minute mark to avoid jumpy resets
    let cap = CGFloat(((secs / 60) + 1) * 60)
    return CGFloat(secs) / cap
}

// MARK: - Color(hex:) convenience (duplicate of main app — widget can't share)

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b, a: UInt64
        switch h.count {
        case 6: (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8: (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
