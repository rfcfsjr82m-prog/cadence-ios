import AppIntents
import WidgetKit

// MARK: - AppEntity
// All snapshot fields are stored directly on the entity so the widget can
// render without a second SharedDefaults lookup (which may fail if the
// system resolves the entity at an unexpected time).

struct TimerWidgetEntity: AppEntity {
    var id: UUID
    var name: String

    // Full snapshot data — persisted by the AppIntents framework alongside id
    var totalMinutes: Int
    var totalRounds: Int
    var blockLabels: [String]
    var blockColorHexes: [String]
    var blockDurationSeconds: [Int]

    nonisolated(unsafe) static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    nonisolated(unsafe) static var defaultQuery = TimerWidgetEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    /// Convert back to a lightweight snapshot for the widget view.
    var snapshot: PinnedTimerSnapshot {
        PinnedTimerSnapshot(
            id: id,
            name: name,
            totalMinutes: totalMinutes,
            totalRounds: totalRounds,
            blockLabels: blockLabels,
            blockColorHexes: blockColorHexes,
            blockDurationSeconds: blockDurationSeconds
        )
    }
}

extension TimerWidgetEntity {
    init(snapshot: PinnedTimerSnapshot) {
        self.id = snapshot.id
        self.name = snapshot.name
        self.totalMinutes = snapshot.totalMinutes
        self.totalRounds = snapshot.totalRounds
        self.blockLabels = snapshot.blockLabels
        self.blockColorHexes = snapshot.blockColorHexes
        self.blockDurationSeconds = snapshot.blockDurationSeconds
    }
}

// MARK: - EntityQuery

struct TimerWidgetEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TimerWidgetEntity] {
        allEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TimerWidgetEntity] {
        allEntities()
    }

    private func allEntities() -> [TimerWidgetEntity] {
        SharedDefaults.readAllSnapshots().map { TimerWidgetEntity(snapshot: $0) }
    }
}

// MARK: - Widget Configuration Intent

struct TimerWidgetIntent: WidgetConfigurationIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Cadence Timers"
    nonisolated(unsafe) static var description = IntentDescription("Choose up to 3 timers to show.")

    @Parameter(title: "First Timer")  var timer1: TimerWidgetEntity?
    @Parameter(title: "Second Timer") var timer2: TimerWidgetEntity?
    @Parameter(title: "Third Timer")  var timer3: TimerWidgetEntity?
}
