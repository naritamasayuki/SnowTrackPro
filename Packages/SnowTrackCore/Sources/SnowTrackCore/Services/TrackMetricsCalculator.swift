import Foundation

/// 滑走パフォーマンスの集計スナップショット
public struct TrackMetricsSummary: Equatable, Sendable {
    /// 累計滑走距離（メートル）
    public let totalDistanceMeters: Double
    /// 最高速度（km/h）
    public let maxSpeedKilometersPerHour: Double
    /// 平均速度（km/h）
    public let averageSpeedKilometersPerHour: Double
    /// 累計獲得滑走標高差（下降分のみ積算、メートル）
    public let verticalDropMeters: Double
    /// 計測経過時間（秒）
    public let elapsedSeconds: TimeInterval

    public init(
        totalDistanceMeters: Double = 0,
        maxSpeedKilometersPerHour: Double = 0,
        averageSpeedKilometersPerHour: Double = 0,
        verticalDropMeters: Double = 0,
        elapsedSeconds: TimeInterval = 0
    ) {
        self.totalDistanceMeters = totalDistanceMeters
        self.maxSpeedKilometersPerHour = maxSpeedKilometersPerHour
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.verticalDropMeters = verticalDropMeters
        self.elapsedSeconds = elapsedSeconds
    }
}

/// GPS軌跡サンプル列から滑走パフォーマンス指標とヒートマップセグメントを算出する計算機
public struct TrackMetricsCalculator: Sendable {
    /// 計算に採用する最大水平誤差（メートル）
    public let maxHorizontalAccuracyMeters: Double
    /// GPSスパイクを除外するための物理的上限速度（km/h）
    public let maxRealisticSpeedKmh: Double
    /// 静止ノイズによる距離加算を防ぐ最小移動距離（メートル）
    public let minSegmentDistanceMeters: Double

    public init(
        maxHorizontalAccuracyMeters: Double = 30.0,
        maxRealisticSpeedKmh: Double = 160.0,
        minSegmentDistanceMeters: Double = 1.5
    ) {
        self.maxHorizontalAccuracyMeters = maxHorizontalAccuracyMeters
        self.maxRealisticSpeedKmh = maxRealisticSpeedKmh
        self.minSegmentDistanceMeters = minSegmentDistanceMeters
    }

    /// 同じ設定の逐次集計アキュムレータを生成する（計測中の O(1) 更新に使う）
    public func makeAccumulator() -> TrackMetricsAccumulator {
        TrackMetricsAccumulator(
            maxHorizontalAccuracyMeters: maxHorizontalAccuracyMeters,
            maxRealisticSpeedKmh: maxRealisticSpeedKmh,
            minSegmentDistanceMeters: minSegmentDistanceMeters
        )
    }

    /// サンプル列から集計メトリクスを算出する（アキュムレータと同一ロジック）
    public func summarize(samples: [TrackSample]) -> TrackMetricsSummary {
        var accumulator = makeAccumulator()
        for sample in samples.sorted(by: { $0.timestamp < $1.timestamp }) {
            accumulator.add(sample)
        }
        return accumulator.summary
    }

    /// 地図描画用の速度別カラーセグメントを生成する
    public func buildSpeedSegments(samples: [TrackSample]) -> [SpeedSegment] {
        let validSamples = samples
            .filter { $0.isValid(maxAccuracyMeters: maxHorizontalAccuracyMeters) }
            .sorted { $0.timestamp < $1.timestamp }

        guard validSamples.count >= 2 else { return [] }

        var segments: [SpeedSegment] = []
        segments.reserveCapacity(validSamples.count - 1)

        for index in 1..<validSamples.count {
            let prev = validSamples[index - 1]
            let curr = validSamples[index]

            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            let distance = ResortMatcher.haversineDistanceMeters(
                lat1: prev.latitude,
                lon1: prev.longitude,
                lat2: curr.latitude,
                lon2: curr.longitude
            )

            if dt > 0, (distance / dt) * 3.6 > maxRealisticSpeedKmh {
                continue
            }

            let speedKmh: Double
            if curr.speedMetersPerSecond >= 0 {
                speedKmh = min(curr.speedKilometersPerHour, maxRealisticSpeedKmh)
            } else if dt > 0 {
                speedKmh = min((distance / dt) * 3.6, maxRealisticSpeedKmh)
            } else {
                speedKmh = 0
            }

            segments.append(
                SpeedSegment(
                    id: index,
                    startLatitude: prev.latitude,
                    startLongitude: prev.longitude,
                    endLatitude: curr.latitude,
                    endLongitude: curr.longitude,
                    speedKilometersPerHour: speedKmh
                )
            )
        }

        return segments
    }
}
