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

// MARK: - Shared UserDefaults bridge

enum SharedDefaults {
    static let suiteName        = "group.com.christiankasper.cadence"
    static let pinnedDataKey    = "pinnedTimerData"
    static let allTimersKey     = "allTimerData"
    static let allSnapshotsKey  = "allTimerSnapshots"

    static var suite: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    static func read() -> [PinnedTimerSnapshot] {
        guard let data = suite.data(forKey: pinnedDataKey),
              let list = try? JSONDecoder().decode([PinnedTimerSnapshot].self, from: data)
        else { return [] }
        return list
    }

    static func write(_ snapshots: [PinnedTimerSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        suite.set(data, forKey: pinnedDataKey)
    }

    static func readAllSnapshots() -> [PinnedTimerSnapshot] {
        guard let data = suite.data(forKey: allSnapshotsKey),
              let list = try? JSONDecoder().decode([PinnedTimerSnapshot].self, from: data)
        else { return [] }
        return list
    }

    static func writeAllSnapshots(_ snapshots: [PinnedTimerSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        suite.set(data, forKey: allSnapshotsKey)
    }
}
