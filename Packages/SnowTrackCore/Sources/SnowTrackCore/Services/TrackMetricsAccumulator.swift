import Foundation

/// サンプルを1点ずつ取り込み O(1) で集計を更新するアキュムレータ。
/// TrackMetricsCalculator.summarize と計測中の逐次集計で同じロジックを共用する。
public struct TrackMetricsAccumulator: Sendable {
    public let maxHorizontalAccuracyMeters: Double
    public let maxRealisticSpeedKmh: Double
    public let minSegmentDistanceMeters: Double
    /// 標高差のヒステリシス幅（m）。この幅未満の上下動はノイズとして無視する
    public let verticalHysteresisMeters: Double
    public let maxVerticalAccuracyMeters: Double
    /// この速度（m/s）未満の点が続く区間は静止ジッターとして距離に加算しない
    public let stationarySpeedMetersPerSecond: Double

    private var firstTimestamp: Date?
    private var lastSample: TrackSample?
    private var distanceAnchor: TrackSample?
    private var altitudeAnchor: Double?
    private var totalDistance: Double = 0
    private var verticalDrop: Double = 0
    private var maxSpeedKmh: Double = 0
    private var consecutiveJumpRejects: Int = 0

    public init(
        maxHorizontalAccuracyMeters: Double = 30.0,
        maxRealisticSpeedKmh: Double = 160.0,
        minSegmentDistanceMeters: Double = 1.5,
        verticalHysteresisMeters: Double = 3.0,
        maxVerticalAccuracyMeters: Double = 20.0,
        stationarySpeedMetersPerSecond: Double = 0.8
    ) {
        self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
        self.maxRealisticSpeedKmh = maxRealisticSpeedKmh
        self.minSegmentDistanceMeters = minSegmentDistanceMeters
        self.verticalHysteresisMeters = verticalHysteresisMeters
        self.maxVerticalAccuracyMeters = maxVerticalAccuracyMeters
        self.stationarySpeedMetersPerSecond = stationarySpeedMetersPerSecond
    }

    public var summary: TrackMetricsSummary {
        guard let firstTimestamp, let lastSample else { return TrackMetricsSummary() }
        let elapsed = max(0, lastSample.timestamp.timeIntervalSince(firstTimestamp))
        let average = elapsed > 0 ? (totalDistance / elapsed) * 3.6 : 0
        return TrackMetricsSummary(
            totalDistanceMeters: totalDistance,
            maxSpeedKilometersPerHour: maxSpeedKmh,
            averageSpeedKilometersPerHour: min(average, maxRealisticSpeedKmh),
            verticalDropMeters: verticalDrop,
            elapsedSeconds: elapsed
        )
    }

    /// 時刻順に1点取り込む（重複・逆順・GPSジャンプの点は捨てる）
    public mutating func add(_ sample: TrackSample) {
        guard sample.isValid(maxAccuracyMeters: maxHorizontalAccuracyMeters) else { return }

        guard let prev = lastSample else {
            firstTimestamp = sample.timestamp
            lastSample = sample
            distanceAnchor = sample
            if sample.hasUsableAltitude(maxVerticalAccuracyMeters: maxVerticalAccuracyMeters) {
                altitudeAnchor = sample.altitudeMeters
            }
            return
        }

        let dt = sample.timestamp.timeIntervalSince(prev.timestamp)
        guard dt > 0 else { return }

        let stepDistance = ResortMatcher.haversineDistanceMeters(
            lat1: prev.latitude, lon1: prev.longitude,
            lat2: sample.latitude, lon2: sample.longitude
        )
        let impliedMetersPerSecond = stepDistance / dt
        // GPSジャンプ：この点を捨て、直前の正常点を基準として保持する
        guard impliedMetersPerSecond * 3.6 <= maxRealisticSpeedKmh else {
            // 3点連続で「ジャンプ」になるのは基準点（lastSample）側が外れ値だったとみなし、距離を足さずに再シードする
            consecutiveJumpRejects += 1
            if consecutiveJumpRejects >= 3 {
                consecutiveJumpRejects = 0
                lastSample = sample
                distanceAnchor = sample
                altitudeAnchor = sample.hasUsableAltitude(maxVerticalAccuracyMeters: maxVerticalAccuracyMeters)
                    ? sample.altitudeMeters : nil
            }
            return
        }
        consecutiveJumpRejects = 0

        // 最高速度：Doppler速度スパイクおよび低精度速度を除外
        if sample.speedMetersPerSecond >= 0 {
            if sample.hasPlausibleSpeed(impliedMetersPerSecond: impliedMetersPerSecond) {
                maxSpeedKmh = max(maxSpeedKmh, min(sample.speedKilometersPerHour, maxRealisticSpeedKmh))
            }
        } else {
            maxSpeedKmh = max(maxSpeedKmh, impliedMetersPerSecond * 3.6)
        }

        // 距離：静止中は加算せず、低速移動はアンカーからの累積で拾う
        // 速度無効（負値）も静止扱い。アンカー方式なので、移動再開時にアンカーからの直線距離として回収される
        let isStationary = prev.speedMetersPerSecond < stationarySpeedMetersPerSecond
            && sample.speedMetersPerSecond < stationarySpeedMetersPerSecond
        if !isStationary, let anchor = distanceAnchor {
            let fromAnchor = ResortMatcher.haversineDistanceMeters(
                lat1: anchor.latitude, lon1: anchor.longitude,
                lat2: sample.latitude, lon2: sample.longitude
            )
            let noiseFloor = max(
                minSegmentDistanceMeters,
                min(anchor.horizontalAccuracyMeters, sample.horizontalAccuracyMeters) * 0.5
            )
            if fromAnchor >= noiseFloor {
                totalDistance += fromAnchor
                distanceAnchor = sample
            }
        }

        // 獲得標高差：ヒステリシス付きアンカーで下降分のみ積算
        if sample.hasUsableAltitude(maxVerticalAccuracyMeters: maxVerticalAccuracyMeters) {
            if let anchor = altitudeAnchor {
                let delta = sample.altitudeMeters - anchor
                if delta <= -verticalHysteresisMeters {
                    verticalDrop += -delta
                    altitudeAnchor = sample.altitudeMeters
                } else if delta >= verticalHysteresisMeters {
                    altitudeAnchor = sample.altitudeMeters
                }
            } else {
                altitudeAnchor = sample.altitudeMeters
            }
        }

        lastSample = sample
    }
}
