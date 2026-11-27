import Foundation

/// 高度変化と移動速度から「滑走中」「リフト乗車中」「休憩中」を判定し、
/// リフト移動を除外した純粋な滑走距離・滑走本数・最高滑走速度を集計するステートマシン
public struct RunStateMachine: Sendable {
    public private(set) var currentState: MotionActivityState = .resting
    /// 完了した滑走本数（リフトを挟んで再度滑走した回数）
    public private(set) var runCount: Int = 0
    /// リフト乗車分を除外した純粋な累計滑走距離（メートル）
    public private(set) var pureSkiDistanceMeters: Double = 0
    /// 純粋な累計滑走時間（秒）
    public private(set) var pureSkiDurationSeconds: TimeInterval = 0
    /// 滑走状態中に記録された、信頼できる最高速度（km/h）
    public private(set) var maxSkiSpeedKmh: Double = 0

    private var lastSample: TrackSample?
    private var lastBarometerRelativeAltitudeMeters: Double?
    private var hasRecordedCurrentRun: Bool = false
    /// リフト確定前に累積した上昇量（メートル）
    private var pendingLiftClimbMeters: Double = 0

    /// 停止とみなす速度閾値（km/h）
    private let restingSpeedThresholdKmh: Double = 3.0
    /// 滑走開始とみなす速度閾値（km/h）
    private let skiingSpeedThresholdKmh: Double = 8.0
    /// リフト上昇判定の最小標高増加率（メートル/秒）
    private let liftClimbRateThresholdMetersPerSecond: Double = 0.25
    /// 休憩・リフトから滑走へ入るときに必要な下降率（m/s）。平地の車移動を滑走と誤判定しない
    private let skiingEntryClimbRateMetersPerSecond: Double = -0.1
    /// この累積上昇を超えたらリフト乗車と確定する（1サンプルの高度ノイズで本数を割らない）
    private let liftConfirmClimbMeters: Double = 10.0

    public init() {}

    /// 新しいGPSサンプル（および任意で気圧計の相対高度）を入力して状態を更新する
    /// 気圧計の相対高度が提供された場合はGPS高度より優先して高精度な上昇/下降判定を行う
    @discardableResult
    public mutating func ingest(
        _ sample: TrackSample,
        barometerRelativeAltitudeMeters: Double? = nil
    ) -> MotionActivityState {
        guard sample.isValid() else {
            return currentState
        }

        guard let prev = lastSample else {
            lastSample = sample
            lastBarometerRelativeAltitudeMeters = barometerRelativeAltitudeMeters
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
        let impliedMetersPerSecond = distance / dt
        let speedKmh = sample.speedMetersPerSecond >= 0
            ? sample.speedKilometersPerHour
            : impliedMetersPerSecond * 3.6

        let altitudeDelta: Double
        if let currentBaro = barometerRelativeAltitudeMeters,
           let prevBaro = lastBarometerRelativeAltitudeMeters {
            altitudeDelta = currentBaro - prevBaro
        } else {
            altitudeDelta = sample.altitudeMeters - prev.altitudeMeters
        }
        let climbRate = altitudeDelta / dt

        let nextState: MotionActivityState
        if speedKmh < restingSpeedThresholdKmh {
            pendingLiftClimbMeters = 0
            nextState = .resting
        } else if climbRate >= liftClimbRateThresholdMetersPerSecond && speedKmh < 30.0 {
            pendingLiftClimbMeters += altitudeDelta
            nextState = (currentState == .ridingLift || pendingLiftClimbMeters >= liftConfirmClimbMeters)
                ? .ridingLift
                : currentState
        } else if speedKmh >= skiingSpeedThresholdKmh
                    && climbRate <= (currentState == .skiing ? 0.1 : skiingEntryClimbRateMetersPerSecond) {
            pendingLiftClimbMeters = 0
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
            if sample.hasPlausibleSpeed(impliedMetersPerSecond: impliedMetersPerSecond) {
                maxSkiSpeedKmh = max(maxSkiSpeedKmh, min(sample.speedKilometersPerHour, 160.0))
            }
        } else if nextState == .ridingLift {
            // リフトに乗車したら次の滑走を新しい1本としてカウントする準備を行う
            hasRecordedCurrentRun = false
        }

        currentState = nextState
        lastSample = sample
        lastBarometerRelativeAltitudeMeters = barometerRelativeAltitudeMeters
        return currentState
    }

    /// 状態を初期化する
    public mutating func reset() {
        currentState = .resting
        runCount = 0
        pureSkiDistanceMeters = 0
        pureSkiDurationSeconds = 0
        maxSkiSpeedKmh = 0
        pendingLiftClimbMeters = 0
        lastSample = nil
        lastBarometerRelativeAltitudeMeters = nil
        hasRecordedCurrentRun = false
    }
}
