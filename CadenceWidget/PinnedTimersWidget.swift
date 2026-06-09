import SwiftUI
import WidgetKit

// MARK: - Timeline entry

struct PinnedTimersEntry: TimelineEntry {
    let date: Date
    let timers: [PinnedTimerSnapshot]
}

// MARK: - Timeline provider

struct PinnedTimersProvider: AppIntentTimelineProvider {
    typealias Intent = TimerWidgetIntent

    private static let placeholderTimers = [
        PinnedTimerSnapshot(id: UUID(), name: "Morning Run",
                            totalMinutes: 25, totalRounds: 8,
                            blockLabels: ["Sprint", "Rest"],
                            blockColorHexes: ["3DD9A4", "A78BFA"],
                            blockDurationSeconds: [30, 60]),
        PinnedTimerSnapshot(id: UUID(), name: "Box Breathing",
                            totalMinutes: 12, totalRounds: 12,
                            blockLabels: ["In", "Hold", "Out", "Hold"],
                            blockColorHexes: ["60B8FF", "A78BFA", "3DD9A4", "F5A623"],
                            blockDurationSeconds: [4, 4, 4, 4]),
        PinnedTimerSnapshot(id: UUID(), name: "Deep Work",
                            totalMinutes: 45, totalRounds: 3,
                            blockLabels: ["Focus", "Break"],
                            blockColorHexes: ["FF7B6B", "86EFAC"],
                            blockDurationSeconds: [25, 5]),
    ]

    func placeholder(in context: Context) -> PinnedTimersEntry {
        PinnedTimersEntry(date: Date(), timers: Self.placeholderTimers)
    }

    func snapshot(for intent: TimerWidgetIntent, in context: Context) async -> PinnedTimersEntry {
        PinnedTimersEntry(date: Date(), timers: resolveTimers(from: intent))
    }

    func timeline(for intent: TimerWidgetIntent, in context: Context) async -> Timeline<PinnedTimersEntry> {
        Timeline(entries: [PinnedTimersEntry(date: Date(), timers: resolveTimers(from: intent))], policy: .never)
    }

    /// Map the three intent slots to actual snapshots from SharedDefaults.
    private func resolveTimers(from intent: TimerWidgetIntent) -> [PinnedTimerSnapshot] {
        let all = SharedDefaults.readAllSnapshots()
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        return [intent.timer1?.id, intent.timer2?.id, intent.timer3?.id]
            .compactMap { $0 }
            .compactMap { map[$0] }
    }
}

// MARK: - Widget declaration

struct PinnedTimersWidget: Widget {
    let kind = "PinnedTimersWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: TimerWidgetIntent.self, provider: PinnedTimersProvider()) { entry in
            PinnedTimersWidgetView(entry: entry)
                .containerBackground(Color(hex: "0F0F11"), for: .widget)
        }
        .configurationDisplayName("My Timers")
        .description("Choose up to 3 timers to show in the widget.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Root view (dispatches to small / medium)

private struct PinnedTimersWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: PinnedTimersEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallPinnedView(timer: entry.timers.first)
        default:
            MediumPinnedView(timers: Array(entry.timers.prefix(3)))
        }
    }
}

// MARK: - Small widget (1 timer)

private struct SmallPinnedView: View {
    let timer: PinnedTimerSnapshot?

    var body: some View {
        if let t = timer {
            VStack(alignment: .leading, spacing: 0) {
                    // Color strip
                    ColorStripView(
                        colorHexes: t.blockColorHexes,
                        durations: t.blockDurationSeconds
                    )
                    .frame(height: 3)

                    VStack(alignment: .leading, spacing: 6) {
                        // Timer name
                        Text(t.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: "F0F0F2"))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Block labels
                        Text(verbatim: t.blockLabels.joined(separator: " · "))
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "8A8A96"))
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        // Stats row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: "\(t.totalMinutes) min")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(Color(hex: "F0F0F2"))
                                Text(verbatim: "\(t.totalRounds) rounds")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "56565E"))
                            }
                            Spacer()
                            // Start chevron
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: "7C6FFF"))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "7C6FFF").opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(12)
            }
            .widgetURL(startURL(t.id))
        } else {
            EmptyPinnedView()
        }
    }
}

// MARK: - Medium widget (up to 3 timers)

private struct MediumPinnedView: View {
    let timers: [PinnedTimerSnapshot]

    var body: some View {
        if timers.isEmpty {
            EmptyPinnedView()
        } else {
            HStack(spacing: 0) {
                ForEach(Array(timers.enumerated()), id: \.element.id) { idx, t in
                    if idx > 0 {
                        // Vertical divider between cards
                        Rectangle()
                            .fill(Color(hex: "FFFFFF").opacity(0.07))
                            .frame(width: 1)
                            .padding(.vertical, 14)
                    }
                    Link(destination: startURL(t.id)) {
                        MediumTimerCard(timer: t)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct MediumTimerCard: View {
    let timer: PinnedTimerSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Color strip across the top of the card
            ColorStripView(
                colorHexes: timer.blockColorHexes,
                durations: timer.blockDurationSeconds
            )
            .frame(height: 3)

            VStack(alignment: .leading, spacing: 5) {
                // Name
                Text(timer.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "F0F0F2"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Block labels
                Text(verbatim: timer.blockLabels.joined(separator: " · "))
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "8A8A96"))
                    .lineLimit(1)

                Spacer(minLength: 0)

                // Stats + play button
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: "\(timer.totalMinutes) min")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(hex: "F0F0F2"))
                        Text(verbatim: "\(timer.totalRounds) rds")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "56565E"))
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(hex: "7C6FFF"))
                        .frame(width: 22, height: 22)
                        .background(Color(hex: "7C6FFF").opacity(0.15))
                        .clipShape(Circle())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty state

private struct EmptyPinnedView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.badge.plus")
                .font(.system(size: 20))
                .foregroundStyle(Color(hex: "56565E"))
            Text("No timers selected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(hex: "56565E"))
            Text("Edit the widget to select your timers.")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "3A3A44"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: - Color strip (proportional block colors)

private struct ColorStripView: View {
    let colorHexes: [String]
    let durations: [Int]

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                let total = durations.reduce(0, +)
                ForEach(Array(colorHexes.enumerated()), id: \.offset) { idx, hex in
                    let dur = idx < durations.count ? durations[idx] : 1
                    let frac = total > 0 ? CGFloat(dur) / CGFloat(total) : 1.0 / CGFloat(colorHexes.count)
                    Color(hex: hex)
                        .frame(width: geo.size.width * frac)
                }
            }
        }
    }
}

// MARK: - Helpers

private func startURL(_ id: UUID) -> URL {
    URL(string: "cadence://start/\(id.uuidString)")!
}

// MARK: - Color(hex:) — duplicated from main app (widget can't share)

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        case 8: (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: 1)
    }
}
