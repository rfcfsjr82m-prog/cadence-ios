import SwiftUI
import WidgetKit

// MARK: - App-wide navigation and session state

@Observable
class AppState {
    var route: Route = .library
    var wizardSession: TimerConfig = .empty()
    var activeSession: TimerConfig? = nil
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
        let configMap = Dictionary(uniqueKeysWithValues: allConfigs.map { ($0.id, $0) })
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
        // Remember which tab to return to after the session ends
        _returnTab = returnTab
        navigate(to: .activeTimer)
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
