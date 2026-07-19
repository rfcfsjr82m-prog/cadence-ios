import Foundation

// Extends SharedDefaults with full TimerConfig read/write.
// Compiled into the main app and Watch targets only — NOT the widget,
// which doesn't need TimerConfig and must stay dependency-free.

extension PinnedTimerSnapshot {
    init(from config: TimerConfig) {
        self.init(
            id: config.id,
            name: config.name,
            totalMinutes: max(1, config.totalDurationSeconds / 60),
            totalRounds: config.totalRounds,
            blockLabels: config.blocks.map(\.label),
            blockColorHexes: config.blocks.map(\.color.hexString),
            blockDurationSeconds: config.blocks.map(\.durationSeconds)
        )
    }
}

extension SharedDefaults {
    static func readAllTimers() -> [TimerConfig] {
        guard let data = suite.data(forKey: allTimersKey),
              let list = try? JSONDecoder().decode([TimerConfig].self, from: data)
        else { return [] }
        return list
    }

    static func writeAllTimers(_ configs: [TimerConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        suite.set(data, forKey: allTimersKey)
    }
}
