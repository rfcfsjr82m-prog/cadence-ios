import SwiftUI

private enum TimerFilter: String, CaseIterable {
    case presets  = "Presets"
    case programs = "Programs"
    case personal = "Personal"
}

struct TimerListView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager.shared
    @State private var filter: TimerFilter = .presets

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter pills
                HStack(spacing: 6) {
                    ForEach(TimerFilter.allCases, id: \.self) { f in
                        Button(NSLocalizedString(f.rawValue, comment: "")) { filter = f }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: filter == f ? .semibold : .regular))
                            .foregroundStyle(filter == f ? .white : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(
                                filter == f ? Color.accent.opacity(0.85) : Color.white.opacity(0.1),
                                in: Capsule()
                            )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)

                // Content
                switch filter {
                case .presets:  presetsView
                case .programs: programsView
                case .personal: personalView
                }
            }
            .navigationTitle("Cadence")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { connectivity.refresh() }
            .refreshable { connectivity.refresh() }
        }
    }

    // MARK: - Presets

    private var presetsView: some View {
        List {
            ForEach(Category.allCases) { category in
                let items = Presets.all.filter { $0.category == category }
                    .sorted { connectivity.pinnedTimerIDs.contains($0.id) && !connectivity.pinnedTimerIDs.contains($1.id) }
                if !items.isEmpty {
                    Section(category.displayName) {
                        ForEach(items) { config in
                            NavigationLink(destination: WatchActiveTimerView(config: config)) {
                                timerRow(config)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Programs

    private var programsView: some View {
        List {
            ForEach(TrainingProtocols.all) { program in
                let done = program.units.filter { connectivity.completedUnitIDs.contains($0.id) }.count
                NavigationLink(destination: ProgramDetailView(program: program, completedIDs: connectivity.completedUnitIDs)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(program.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(String(format: NSLocalizedString("%d/%d units done", comment: ""), done, program.units.count))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.carousel)
    }

    // MARK: - Personal

    @ViewBuilder
    private var personalView: some View {
        if connectivity.personalTimers.isEmpty {
            ContentUnavailableView(
                "No Personal Timers",
                systemImage: "timer",
                description: Text("Create timers in Cadence on iPhone.")
            )
        } else {
            List {
                ForEach(Category.allCases) { category in
                    let items = connectivity.personalTimers.filter { $0.category == category }
                        .sorted { connectivity.pinnedTimerIDs.contains($0.id) && !connectivity.pinnedTimerIDs.contains($1.id) }
                    if !items.isEmpty {
                        Section(category.displayName) {
                            ForEach(items) { config in
                                NavigationLink(destination: WatchActiveTimerView(config: config)) {
                                    timerRow(config)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.carousel)
        }
    }

    // MARK: - Row

    private func timerRow(_ config: TimerConfig) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if connectivity.pinnedTimerIDs.contains(config.id) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.accent)
                        .rotationEffect(.degrees(45))
                }
                Text(config.name)
                    .font(.headline)
                    .lineLimit(1)
            }
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(config.blocks.prefix(4)) { block in
                        Circle()
                            .fill(block.color.color)
                            .frame(width: 6, height: 6)
                    }
                }
                Text(String(format: NSLocalizedString("%dm · %d×", comment: ""), config.totalDurationMinutes, config.totalRounds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
