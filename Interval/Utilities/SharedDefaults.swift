import Foundation

// MARK: - Lightweight timer snapshot shared via App Group
//
// This file is compiled into BOTH the main app target and the widget extension.
// Keep it dependency-free — no SwiftUI, no SwiftData, no app-only types.

struct PinnedTimerSnapshot: Codable, Identifiable {
    var id: UUID
    var name: String
    var totalMinutes: Int
    var totalRounds: Int
    var blockLabels: [String]
    var blockColorHexes: [String]   // e.g. "3DD9A4"
    var blockDurationSeconds: [Int] // raw durations, used to compute strip fractions
}

// MARK: - Shared storage bridge (App Group container file + UserDefaults fallback)

enum SharedDefaults {
    static let suiteName        = "group.com.christiankasper.cadence"
    static let pinnedDataKey    = "pinnedTimerData"
    static let allTimersKey     = "allTimerData"
    static let allSnapshotsKey  = "allTimerSnapshots"

    // MARK: UserDefaults suite (for simple keys)
    static var suite: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    // MARK: App Group container URL
    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
    }

    private static func fileURL(named name: String) -> URL? {
        containerURL?.appendingPathComponent(name)
    }

    // MARK: - Pinned snapshots (shown in widget based on pin state)

    static func read() -> [PinnedTimerSnapshot] {
        readSnapshots(file: "pinned_snapshots.json") ?? []
    }

    static func write(_ snapshots: [PinnedTimerSnapshot]) {
        writeSnapshots(snapshots, file: "pinned_snapshots.json")
        // Also keep UserDefaults in sync as fallback
        if let data = try? JSONEncoder().encode(snapshots) {
            suite.set(data, forKey: pinnedDataKey)
        }
    }

    // MARK: - Widget small-timer index (which of the selected timers is shown)

    static func widgetTimerIndex() -> Int {
        suite.integer(forKey: "widgetTimerIndex")
    }

    static func setWidgetTimerIndex(_ index: Int) {
        suite.set(index, forKey: "widgetTimerIndex")
    }

    // MARK: - Widget-selected timers (chosen in-app, up to 3)

    static func readWidgetTimers() -> [PinnedTimerSnapshot] {
        readSnapshots(file: "widget_timers.json") ?? []
    }

    static func writeWidgetTimers(_ snapshots: [PinnedTimerSnapshot]) {
        writeSnapshots(snapshots, file: "widget_timers.json")
    }

    // MARK: - All timer snapshots (for entity picker)

    static func readAllSnapshots() -> [PinnedTimerSnapshot] {
        // Try file first (most reliable cross-process), fall back to UserDefaults
        if let list = readSnapshots(file: "all_snapshots.json"), !list.isEmpty {
            return list
        }
        guard let data = suite.data(forKey: allSnapshotsKey),
              let list = try? JSONDecoder().decode([PinnedTimerSnapshot].self, from: data)
        else { return [] }
        return list
    }

    static func writeAllSnapshots(_ snapshots: [PinnedTimerSnapshot]) {
        writeSnapshots(snapshots, file: "all_snapshots.json")
        // Also write to UserDefaults as fallback
        if let data = try? JSONEncoder().encode(snapshots) {
            suite.set(data, forKey: allSnapshotsKey)
        }
    }

    // MARK: - File helpers

    private static func readSnapshots(file: String) -> [PinnedTimerSnapshot]? {
        guard let url = fileURL(named: file),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([PinnedTimerSnapshot].self, from: data)
        else { return nil }
        return list
    }

    private static func writeSnapshots(_ snapshots: [PinnedTimerSnapshot], file: String) {
        guard let url = fileURL(named: file),
              let data = try? JSONEncoder().encode(snapshots)
        else { return }
        try? data.write(to: url, options: .atomic)
    }
}
