import SwiftUI
import WidgetKit

// MARK: - Active-session persistence
//
// A running session is snapshotted to disk so it survives the app being
// suspended or terminated in the background. Because timing is anchored to
// wall-clock (`anchorDate` + `elapsedAtAnchor`), the exact elapsed time can be
// reconstructed at any later moment — even after a cold relaunch triggered by
// tapping the lock-screen Live Activity.

struct ActiveSessionSnapshot: Codable {
    var config: TimerConfig
    /// Wall-clock instant that corresponds to `elapsedAtAnchor` seconds elapsed.
    var anchorDate: Date
    /// Elapsed seconds captured at `anchorDate`.
    var elapsedAtAnchor: Int
    var isPaused: Bool

    /// Live elapsed seconds reconstructed from wall-clock.
    var currentElapsed: Int {
        if isPaused { return elapsedAtAnchor }
        return elapsedAtAnchor + max(0, Int(Date().timeIntervalSince(anchorDate)))
    }
}

enum ActiveSessionStore {
    private static let key = "activeSessionSnapshot"

    static func save(_ snapshot: ActiveSessionSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> ActiveSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(ActiveSessionSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// MARK: - App-wide navigation and session state

@Observable
class AppState {
    var route: Route = .library
    var wizardSession: TimerConfig = .empty()
    var activeSession: TimerConfig? = nil
    /// Set when a persisted session is being restored, so `ActiveTimerView`
    /// picks up its timing instead of starting from zero. Cleared once consumed.
    var pendingRestore: ActiveSessionSnapshot? = nil
    var editingSessionID: UUID? = nil
    var selectedTab: LibraryTab
    var shuffledPresetIDs: [UUID]

    // ── Protocol unit completion ─────────────────────────────────────────────
    // Persisted as an array of UUID strings in UserDefaults.
    // A unit is "complete" when its session reaches a natural end (not stopped).
    private(set) var completedUnitIDs: Set<UUID>

    // ── Widget picker sheet ──────────────────────────────────────────────────
    var showWidgetPicker: Bool = false

    // ── Pinned timers ────────────────────────────────────────────────────────
    // Sorted to top in the Presets and Personal tabs.
    private(set) var pinnedTimerIDs: Set<UUID>

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedTab")
        selectedTab = (saved == "personal") ? .personal
                    : (saved == "programs") ? .programs
                    : .presets
        shuffledPresetIDs = Presets.all.map(\.id).shuffled()

        let stored = UserDefaults.standard.stringArray(forKey: "completedUnitIDs") ?? []
        completedUnitIDs = Set(stored.compactMap { UUID(uuidString: $0) })

        let storedPinned = UserDefaults.standard.stringArray(forKey: "pinnedTimerIDs") ?? []
        pinnedTimerIDs = Set(storedPinned.compactMap { UUID(uuidString: $0) })

    }

    /// Call this when a protocol unit session reaches its natural end.
    func markUnitCompleted(_ id: UUID) {
        completedUnitIDs.insert(id)
        UserDefaults.standard.set(
            completedUnitIDs.map { $0.uuidString },
            forKey: "completedUnitIDs"
        )
    }

    func togglePin(_ id: UUID) {
        if pinnedTimerIDs.contains(id) {
            pinnedTimerIDs.remove(id)
        } else {
            pinnedTimerIDs.insert(id)
        }
        UserDefaults.standard.set(
            pinnedTimerIDs.map { $0.uuidString },
            forKey: "pinnedTimerIDs"
        )
        // Caller should follow up with syncPinnedSnapshots(allConfigs:)
        // so the widget gets fresh data. We trigger the reload here as a
        // best-effort even before the snapshots are written.
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedTimersWidget")
    }

    /// Write pinned timer snapshots to the shared App Group so the widget displays them.
    func syncPinnedSnapshots(allConfigs: [TimerConfig]) {
        // CloudKit can transiently produce two PersistedSessions with the same
        // id (the `.unique` constraint is dropped when mirroring), and the
        // dedup pass in RootView may not have flushed yet. `uniqueKeysWithValues`
        // TRAPS on a duplicate key, so uniquing-keys is used to keep the first.
        let configMap = Dictionary(allConfigs.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })
        let pinned = pinnedTimerIDs.compactMap { configMap[$0] }.map { c in
            PinnedTimerSnapshot(
                id: c.id, name: c.name,
                totalMinutes: max(1, c.totalDurationSeconds / 60),
                totalRounds: c.totalRounds,
                blockLabels: c.blocks.map(\.label),
                blockColorHexes: c.blocks.map(\.color.hexString),
                blockDurationSeconds: c.blocks.map(\.durationSeconds)
            )
        }
        SharedDefaults.write(pinned)
        WidgetCenter.shared.reloadTimelines(ofKind: "PinnedTimersWidget")
    }

    func setSelectedTab(_ tab: LibraryTab) {
        selectedTab = tab
        let key: String
        switch tab {
        case .presets:  key = "presets"
        case .programs: key = "programs"
        case .personal: key = "personal"
        }
        UserDefaults.standard.set(key, forKey: "selectedTab")
    }

    // MARK: Transition helpers

    func startWizard(editing config: TimerConfig? = nil) {
        if let config {
            wizardSession = config
            editingSessionID = config.id
        } else {
            wizardSession = TimerConfig.empty()
            editingSessionID = nil
        }
        navigate(to: .wizardStep1)
    }

    func navigate(to destination: Route) {
        withAnimation(.easeInOut(duration: 0.32)) {
            route = destination
        }
    }

    func startSession(_ config: TimerConfig, returnTab: LibraryTab? = nil) {
        activeSession = config
        pendingRestore = nil
        // Remember which tab to return to after the session ends
        _returnTab = returnTab
        navigate(to: .activeTimer)
    }

    /// Restores a session that outlived the app (suspended/terminated in the
    /// background while its Live Activity kept running). Set directly without an
    /// animated transition so a cold launch lands straight on the timer.
    func restoreActiveSession(_ snapshot: ActiveSessionSnapshot) {
        activeSession = snapshot.config
        pendingRestore = snapshot
        _returnTab = nil
        route = .activeTimer
    }

    private var _returnTab: LibraryTab? = nil

    func endSession() {
        if let tab = _returnTab {
            setSelectedTab(tab)
        } else if let session = activeSession {
            setSelectedTab(session.isPreset ? .presets : .personal)
        }
        _returnTab = nil
        activeSession = nil
        pendingRestore = nil
        ActiveSessionStore.clear()
        navigate(to: .library)
    }
}

enum LibraryTab { case presets, programs, personal }

enum Route {
    case library
    case wizardStep1
    case wizardStep2
    case activeTimer
    case settings
}
