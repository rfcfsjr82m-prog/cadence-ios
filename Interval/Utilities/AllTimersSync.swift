import Foundation

// Extends SharedDefaults with full TimerConfig read/write.
// Compiled into the main app and Watch targets only — NOT the widget,
// which doesn't need TimerConfig and must stay dependency-free.

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
