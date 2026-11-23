import ActivityKit
import Foundation

/// ロック画面・Dynamic Island（Live Activities）用の属性およびリアルタイム状態定義
struct SnowTrackActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var resortName: String
        var currentSpeedKmh: Double
        var maxSpeedKmh: Double
        var distanceMeters: Double
        var runCount: Int
        var activityLabel: String
    }

    var sessionStartedAt: Date
}

/// Live Activities（ロック画面／Dynamic Island）の開始・更新・終了を Swift 6 並行性安全に管理するマネージャー
@MainActor
final class TrackingActivityManager {
    private var activeActivityID: String?

    /// Live Activity を開始する（未許可または非対応環境では安全にスキップ）
    func start(resortName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            AppLogger.tracking.info("Live Activities が無効のためスキップします。")
            return
        }

        let attributes = SnowTrackActivityAttributes(sessionStartedAt: Date())
        let initialState = SnowTrackActivityAttributes.ContentState(
            resortName: resortName,
            currentSpeedKmh: 0,
            maxSpeedKmh: 0,
            distanceMeters: 0,
            runCount: 0,
            activityLabel: String(localized: "state.resting")
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            activeActivityID = activity.id
            AppLogger.tracking.info("Live Activity を開始しました。")
        } catch {
            AppLogger.tracking.error("Live Activity の開始に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// リアルタイム滑走数値を Live Activity へ反映する
    func update(
        resortName: String,
        currentSpeedKmh: Double,
        maxSpeedKmh: Double,
        distanceMeters: Double,
        runCount: Int,
        activityLabel: String
    ) {
        guard let targetID = activeActivityID else { return }
        let updatedState = SnowTrackActivityAttributes.ContentState(
            resortName: resortName,
            currentSpeedKmh: currentSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            distanceMeters: distanceMeters,
            runCount: runCount,
            activityLabel: activityLabel
        )
        Task.detached {
            guard let activity = Activity<SnowTrackActivityAttributes>.activities.first(where: { $0.id == targetID }) else {
                return
            }
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    /// 計測終了時に Live Activity を終了する
    func end() {
        guard let targetID = activeActivityID else { return }
        activeActivityID = nil
        Task.detached {
            guard let activity = Activity<SnowTrackActivityAttributes>.activities.first(where: { $0.id == targetID }) else {
                return
            }
            await activity.end(nil, dismissalPolicy: .immediate)
            AppLogger.tracking.info("Live Activity を終了しました。")
        }
    }
}
