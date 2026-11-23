import Foundation
import HealthKit

/// Apple ヘルスケア（HealthKit）へスキー／スノーボードのワークアウトを記録するサービス
@MainActor
final class HealthKitWorkoutService {
    private let healthStore = HKHealthStore()

    /// 端末が HealthKit をサポートしているか
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// 滑走セッションをダウンヒルスキーのワークアウトとして Apple ヘルスケアへ保存する
    func saveSkiWorkout(
        startedAt: Date,
        endedAt: Date,
        totalDistanceMeters: Double,
        resortName: String
    ) async throws {
        guard isAvailable else {
            throw HealthKitError.unavailable
        }

        let workoutType = HKObjectType.workoutType()
        let distanceType = HKQuantityType(.distanceDownhillSnowSports)
        let typesToShare: Set<HKSampleType> = [workoutType, distanceType]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: [])

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .downhillSkiing
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())
        try await builder.beginCollection(at: startedAt)

        if totalDistanceMeters > 0 {
            let quantity = HKQuantity(unit: .meter(), doubleValue: totalDistanceMeters)
            let distanceSample = HKQuantitySample(
                type: distanceType,
                quantity: quantity,
                start: startedAt,
                end: endedAt
            )
            try await builder.addSamples([distanceSample])
        }

        try await builder.addMetadata([
            HKMetadataKeyIndoorWorkout: false,
            "ResortName": resortName
        ])
        try await builder.endCollection(at: endedAt)
        _ = try await builder.finishWorkout()
        AppLogger.persistence.info("Apple ヘルスケアへスキーワークアウトを保存しました。")
    }
}

enum HealthKitError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return String(localized: "healthkit.error.unavailable")
        }
    }
}
