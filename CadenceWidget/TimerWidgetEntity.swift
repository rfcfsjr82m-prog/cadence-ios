import AppIntents
import WidgetKit

// TimerWidgetEntity kept for future AppIntentConfiguration use,
// but the widget currently uses StaticConfiguration + in-app selection.

struct TimerWidgetEntity: AppEntity {
    var id: String
    var name: String

    nonisolated(unsafe) static var typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    nonisolated(unsafe) static var defaultQuery = TimerWidgetEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TimerWidgetEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TimerWidgetEntity] {
        SharedDefaults.readAllSnapshots()
            .filter { identifiers.contains($0.id.uuidString) }
            .map { TimerWidgetEntity(id: $0.id.uuidString, name: $0.name) }
    }
    func suggestedEntities() async throws -> [TimerWidgetEntity] {
        SharedDefaults.readAllSnapshots().map { TimerWidgetEntity(id: $0.id.uuidString, name: $0.name) }
    }
}
