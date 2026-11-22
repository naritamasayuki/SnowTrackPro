import Foundation

/// 高度変化と移動速度から「滑走中」「リフト乗車中」「休憩中」を判定し、
/// リフト移動を除外した純粋な滑走距離・滑走本数を集計するステートマシン
public struct RunStateMachine: Sendable {
    public private(set) var currentState: MotionActivityState = .resting
    /// 完了した滑走本数（リフトを挟んで再度滑走した回数）
    public private(set) var runCount: Int = 0
    /// リフト乗車分を除外した純粋な累計滑走距離（メートル）
    public private(set) var pureSkiDistanceMeters: Double = 0
    /// 純粋な累計滑走時間（秒）
    public private(set) var pureSkiDurationSeconds: TimeInterval = 0

    private var lastSample: TrackSample?
    private var hasRecordedCurrentRun: Bool = false

    /// 停止とみなす速度閾値（km/h）
    private let restingSpeedThresholdKmh: Double = 3.0
    /// 滑走開始とみなす速度閾値（km/h）
    private let skiingSpeedThresholdKmh: Double = 8.0
    /// リフト上昇判定の最小標高増加率（メートル/秒）
    private let liftClimbRateThresholdMetersPerSecond: Double = 0.25

    public init() {}

    /// 新しいGPSサンプルを入力して状態を更新する
    @discardableResult
    public mutating func ingest(_ sample: TrackSample) -> MotionActivityState {
        guard sample.isValid() else {
            return currentState
        }

        guard let prev = lastSample else {
            lastSample = sample
            return currentState
        }

        let dt = sample.timestamp.timeIntervalSince(prev.timestamp)
        guard dt > 0 else {
            return currentState
        }

        let distance = ResortMatcher.haversineDistanceMeters(
            lat1: prev.latitude,
            lon1: prev.longitude,
            lat2: sample.latitude,
            lon2: sample.longitude
        )
        let speedKmh = sample.speedMetersPerSecond >= 0
            ? sample.speedKilometersPerHour
            : (distance / dt) * 3.6
        let climbRate = (sample.altitudeMeters - prev.altitudeMeters) / dt

        let nextState: MotionActivityState
        if speedKmh < restingSpeedThresholdKmh {
            nextState = .resting
        } else if climbRate >= liftClimbRateThresholdMetersPerSecond && speedKmh < 30.0 {
            nextState = .ridingLift
        } else if speedKmh >= skiingSpeedThresholdKmh && climbRate <= 0.1 {
            nextState = .skiing
        } else {
            nextState = currentState
        }

        if nextState == .skiing {
            if !hasRecordedCurrentRun {
                runCount += 1
                hasRecordedCurrentRun = true
            }
            if distance <= 160.0 / 3.6 * dt {
                pureSkiDistanceMeters += distance
                pureSkiDurationSeconds += dt
            }
        } else if nextState == .ridingLift {
            // リフトに乗車したら次の滑走を新しい1本としてカウントする準備を行う
            hasRecordedCurrentRun = false
        }

        currentState = nextState
        lastSample = sample
        return currentState
    }

    /// 状態を初期化する
    public mutating func reset() {
        currentState = .resting
        runCount = 0
        pureSkiDistanceMeters = 0
        pureSkiDurationSeconds = 0
        lastSample = nil
        hasRecordedCurrentRun = false
    }
}
