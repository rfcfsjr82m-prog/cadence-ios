import AppIntents
import WidgetKit

// MARK: - AppEntity

struct TimerWidgetEntity: AppEntity {
    var id: UUID
    var name: String

    nonisolated(unsafe) static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    nonisolated(unsafe) static var defaultQuery = TimerWidgetEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
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
        SharedDefaults.readAllSnapshots().map { TimerWidgetEntity(id: $0.id, name: $0.name) }
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
