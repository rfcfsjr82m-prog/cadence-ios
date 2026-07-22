import Foundation
import SwiftData

// MARK: - SwiftData persistence wrapper

@Model
final class PersistedSession {
    // NOTE: No `@Attribute(.unique)` and every property has a default value —
    // both are hard requirements for the SwiftData + CloudKit mirrored store.
    // Uniqueness of `id` is enforced manually (seeding checks existence; a
    // launch-time dedup pass in `RootView.onAppear` collapses any records that
    // two devices seeded independently before syncing).
    var id: UUID = UUID()
    var payload: Data = Data()
    var createdAt: Date = Date()
    var isPreset: Bool = false

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
