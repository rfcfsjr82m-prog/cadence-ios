import Foundation
import SwiftData

// MARK: - SwiftData persistence wrapper

@Model
final class PersistedSession {
    @Attribute(.unique) var id: UUID
    var payload: Data
    var createdAt: Date
    var isPreset: Bool

    init(config: TimerConfig) {
        self.id = config.id
        self.payload = (try? JSONEncoder().encode(config)) ?? Data()
        self.createdAt = config.createdAt
        self.isPreset = config.isPreset
    }

    func config() -> TimerConfig? {
        try? JSONDecoder().decode(TimerConfig.self, from: payload)
    }

    func update(with config: TimerConfig) {
        payload = (try? JSONEncoder().encode(config)) ?? Data()
        createdAt = config.createdAt
    }
}
