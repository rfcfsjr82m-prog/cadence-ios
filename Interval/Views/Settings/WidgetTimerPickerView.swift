import SwiftUI
import WidgetKit

struct WidgetTimerPickerView: View {
    @Environment(\.dismiss) private var dismiss

    // All available timers (read from shared storage)
    private let allTimers: [PinnedTimerSnapshot] = SharedDefaults.readAllSnapshots()

    // Currently selected widget timer IDs
    @State private var selectedIDs: [UUID]

    init() {
        let current = SharedDefaults.readWidgetTimers().map(\.id)
        _selectedIDs = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bg.ignoresSafeArea()
                if allTimers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "timer")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.textTertiary)
                        Text("No timers yet")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.textSecondary)
                        Text("Create a timer first, then come back to add it to the widget.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Header
                            Text("Choose up to 3 timers to show in the widget. Tap to add or remove.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)

                            // Timer list
                            VStack(spacing: 1) {
                                ForEach(allTimers) { timer in
                                    WidgetTimerRow(
                                        timer: timer,
                                        position: positionLabel(for: timer.id),
                                        isSelected: selectedIDs.contains(timer.id),
                                        canAdd: selectedIDs.count < 3
                                    ) {
                                        toggle(timer.id)
                                    }
                                }
                            }
                            .background(Color.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.borderDefault, lineWidth: 0.5))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }
            .navigationTitle("Widget Timers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accent)
                }
            }
        }
    }

    // MARK: - Helpers

    private func positionLabel(for id: UUID) -> String? {
        guard let idx = selectedIDs.firstIndex(of: id) else { return nil }
        return "\(idx + 1)"
    }

    private func toggle(_ id: UUID) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else if selectedIDs.count < 3 {
            selectedIDs.append(id)
        }
    }

    private func save() {
        // Duplicate ids can occur (CloudKit drops the `.unique` constraint when
        // mirroring), and `uniqueKeysWithValues` traps on them — unique the keys.
        let map = Dictionary(allTimers.map { ($0.id, $0) },
                             uniquingKeysWith: { first, _ in first })
        let selected = selectedIDs.compactMap { map[$0] }
        SharedDefaults.writeWidgetTimers(selected)
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedTimersWidget")
    }
}

// MARK: - Row

private struct WidgetTimerRow: View {
    let timer: PinnedTimerSnapshot
    let position: String?
    let isSelected: Bool
    let canAdd: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Position badge or empty circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accent : Color.surface2)
                        .frame(width: 28, height: 28)
                    if let pos = position {
                        Text(pos)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(canAdd ? Color.textSecondary : Color.textTertiary)
                    }
                }

                // Color strip + name
                VStack(alignment: .leading, spacing: 4) {
                    // Mini color strip
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            let total = timer.blockDurationSeconds.reduce(0, +)
                            ForEach(Array(timer.blockColorHexes.enumerated()), id: \.offset) { idx, hex in
                                let dur = idx < timer.blockDurationSeconds.count ? timer.blockDurationSeconds[idx] : 1
                                let frac = total > 0 ? CGFloat(dur) / CGFloat(total) : 1.0 / CGFloat(timer.blockColorHexes.count)
                                Color(hexStr: hex).frame(width: geo.size.width * frac)
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 3)

                    Text(timer.name)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.textPrimary)
                    Text("\(timer.totalMinutes) min · \(timer.totalRounds) rounds")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .opacity((!isSelected && !canAdd) ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

private extension Color {
    init(hexStr: String) {
        let h = hexStr.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: UInt64
        switch h.count {
        case 6: (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: 1)
    }
}
