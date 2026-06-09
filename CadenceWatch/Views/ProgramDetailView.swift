import SwiftUI

struct ProgramDetailView: View {
    let program: TrainingProtocol
    let completedIDs: Set<UUID>

    var body: some View {
        List {
            ForEach(Array(program.units.enumerated()), id: \.element.id) { index, unit in
                let done = completedIDs.contains(unit.id)
                NavigationLink(destination: WatchActiveTimerView(config: unit)) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: NSLocalizedString("Unit %d", comment: ""), index + 1))
                                .font(.headline)
                                .lineLimit(1)
                            Text(String(format: NSLocalizedString("%dm · %d×", comment: ""), unit.totalDurationMinutes, unit.totalRounds))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if done {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                        }
                    }
                    .opacity(done ? 0.5 : 1)
                }
            }
        }
        .listStyle(.carousel)
        .navigationTitle(program.name)
    }
}
