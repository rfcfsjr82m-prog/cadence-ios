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
                        CountdownText.session(context.state)
                            .font(.system(size: 22, design: .monospaced).weight(.thin))
                            .foregroundStyle(.white)
                            .frame(minWidth: 62, alignment: .trailing)
                    }
                    .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SessionProgressBar(state: context.state)
                        .frame(height: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(hex: context.state.blockColorHex))
            } compactTrailing: {
                CountdownText.session(context.state)
                    .font(.system(size: 13, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 38, alignment: .trailing)
            } minimal: {
                CountdownText.session(context.state)
                    .font(.system(size: 11, design: .monospaced).weight(.medium))
                    .foregroundStyle(Color(hex: context.state.blockColorHex))
                    .monospacedDigit()
            }
            .widgetURL(URL(string: "cadence://resume"))
        }
    }
}

// MARK: - Live countdown text
//
// While running, renders `Text(timerInterval:)` so the system counts down on its
// own — accurate even when the app is suspended. While paused it falls back to a
// static value (a live countdown can't be frozen).
//
// The SESSION countdown (`.session`) counts to a fixed end date for the whole
// workout, so it stays correct for the entire session from a single push — it can
// never freeze mid-session, even if the app is suspended the whole time. That's
// why it is the hero number. The BLOCK countdown (`.block`) resets every phase and
// needs a fresh push at each boundary, so it is only ever a secondary detail.

struct CountdownText: View {
    let start: Date
    let end: Date
    let pausedSeconds: Int
    let isPaused: Bool

    static func session(_ s: CadenceActivityAttributes.ContentState) -> CountdownText {
        CountdownText(start: s.sessionStartDate, end: s.sessionEndDate,
                      pausedSeconds: s.totalLeftAtPause, isPaused: s.isPaused)
    }

    static func block(_ s: CadenceActivityAttributes.ContentState) -> CountdownText {
        CountdownText(start: s.blockStartDate, end: s.blockEndDate,
                      pausedSeconds: s.blockLeftAtPause, isPaused: s.isPaused)
    }

    var body: some View {
        if isPaused {
            Text(formatTime(pausedSeconds))
                .monospacedDigit()
        } else {
            Text(timerInterval: countdownRange(from: start, to: end), showsHours: false)
                .monospacedDigit()
        }
    }
}

// MARK: - Live progress bar (whole-session progress — never freezes)

struct SessionProgressBar: View {
    let state: CadenceActivityAttributes.ContentState

    var body: some View {
        let color = Color(hex: state.blockColorHex)
        if state.isPaused {
            ProgressBar(fraction: sessionElapsedFraction(state), color: color)
        } else {
            ProgressView(timerInterval: countdownRange(from: state.sessionStartDate,
                                                        to: state.sessionEndDate),
                         countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(color)
        }
    }
}

/// Fraction of the whole session already elapsed, from the frozen paused values.
private func sessionElapsedFraction(_ s: CadenceActivityAttributes.ContentState) -> CGFloat {
    let total = s.sessionEndDate.timeIntervalSince(s.sessionStartDate)
    guard total > 0 else { return 0 }
    return CGFloat(max(0, min(1, 1 - Double(s.totalLeftAtPause) / total)))
}

/// Clamps an interval so its lower bound never sits in the future relative to a
/// slightly-stale render (which would make `Text(timerInterval:)` misbehave).
private func countdownRange(from start: Date, to end: Date) -> ClosedRange<Date> {
    let safeStart = min(start, end)
    return safeStart...max(safeStart, end)
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

            // Time remaining. The big number is the WHOLE-SESSION countdown,
            // which counts to a fixed end date and therefore never freezes — even
            // if the app is suspended across phase boundaries. The small line
            // shows the current phase's remaining time as a secondary detail.
            VStack(alignment: .trailing, spacing: 2) {
                CountdownText.session(state)
                    .font(.system(size: 32, design: .monospaced).weight(.thin))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .frame(minWidth: 92, alignment: .trailing)
                if state.isPaused {
                    Text("Paused")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                } else {
                    HStack(spacing: 3) {
                        CountdownText.block(state)
                        Text("this phase")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Tapping the lock-screen Live Activity re-opens the running session
        // instead of cold-launching to the library.
        .widgetURL(URL(string: "cadence://resume"))
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
