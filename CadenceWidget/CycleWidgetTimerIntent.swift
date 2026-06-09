import AppIntents
import WidgetKit

struct CycleWidgetTimerIntent: AppIntent {
    nonisolated(unsafe) static var title: LocalizedStringResource = "Next Timer"
    nonisolated(unsafe) static var description = IntentDescription("Cycle to the next timer in the widget.")

    // direction: +1 = next, -1 = prev
    @Parameter(title: "Direction") var direction: Int

    init() { self.direction = 1 }
    init(direction: Int) { self.direction = direction }

    func perform() async throws -> some IntentResult {
        let timers = SharedDefaults.readWidgetTimers()
        guard timers.count > 1 else { return .result() }
        let current = SharedDefaults.widgetTimerIndex()
        let next = (current + direction + timers.count) % timers.count
        SharedDefaults.setWidgetTimerIndex(next)
        return .result()
    }
}
