import HealthKit
import Foundation

// MARK: - Saves completed Interval sessions to Apple Health

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else {
            print("[HealthKit] Health data not available on this device.")
            return
        }
        let writeTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.categoryType(forIdentifier: .mindfulSession)!
        ]
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: [])
            let status = store.authorizationStatus(for: HKObjectType.workoutType())
            print("[HealthKit] Authorization request completed. Workout share status: \(status.rawValue)")
        } catch {
            // A thrown error here usually means the HealthKit entitlement is
            // missing from the build's provisioning profile (e.g. signed with
            // a team that doesn't have the HealthKit capability).
            print("[HealthKit] Authorization request failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Save session

    func save(config: TimerConfig, startDate: Date, endDate: Date) async throws {
        guard isAvailable else { return }

        switch config.category {
        case .mind, .productivity:
            let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession)!
            let sample = HKCategorySample(
                type: mindfulType,
                value: HKCategoryValue.notApplicable.rawValue,
                start: startDate,
                end: endDate,
                metadata: [HKMetadataKeyWorkoutBrandName: "Interval"]
            )
            try await store.save(sample)

        case .physical:
            let workoutConfig = HKWorkoutConfiguration()
            workoutConfig.activityType = .highIntensityIntervalTraining

            let builder = HKWorkoutBuilder(
                healthStore: store,
                configuration: workoutConfig,
                device: .local()
            )
            try await builder.beginCollection(at: startDate)
            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
        }
    }
}
