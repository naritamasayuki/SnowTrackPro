import Foundation

/// ターンの弧の大きさ傾向
public enum TurnArcStyle: String, Codable, Equatable, Sendable {
    /// ショートターン寄り（切り返しが多い）
    case short
    /// ミドルターン（バランス型）
    case medium
    /// ロングターン寄り（大きな弧）
    case long
}

/// 3軸ジャイロセンサーの単一サンプル（rad/s）
public struct GyroSample: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let x: Double
    public let y: Double
    public let z: Double

    public init(timestamp: Date, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
    }

    /// 端末のポケット内の向きに依存しない3軸合成角速度ノルム（rad/s）
    public var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }
}

/// 1セッション分のターン解析メトリクス
public struct TurnMetrics: Codable, Equatable, Sendable {
    /// 検出された総ターン数
    public let turnCount: Int
    /// 1km あたりのターン密度
    public let turnsPerKilometer: Double
    /// ターン弧のスタイル傾向
    public let arcStyle: TurnArcStyle
    /// ターン間隔の安定度スコア（0〜100）
    public let consistencyScore: Double

    public init(
        turnCount: Int,
        turnsPerKilometer: Double,
        arcStyle: TurnArcStyle,
        consistencyScore: Double
    ) {
        self.turnCount = max(0, turnCount)
        self.turnsPerKilometer = max(0, turnsPerKilometer)
        self.arcStyle = arcStyle
        self.consistencyScore = min(100, max(0, consistencyScore))
    }

    /// 1km あたりのターン密度からターン弧スタイルを分類する
    public static func classifyArcStyle(turnsPerKilometer: Double) -> TurnArcStyle {
        switch turnsPerKilometer {
        case 35.0...:
            return .short
        case 18.0..<35.0:
            return .medium
        default:
            return .long
        }
    }
}

/// 端末の向きに依存しない3軸角速度ノルムからターン数・リズム安定度を解析するアナライザ
public struct TurnAnalyzer: Sendable {
    /// ターン切り返しピークとみなす角速度ノルム閾値（rad/s）
    public let peakThresholdRadPerSec: Double
    /// 連続誤カウント（コブの微振動等）を防ぐ最小ターン間隔（秒）
    public let minTurnIntervalSeconds: TimeInterval

    public init(
        peakThresholdRadPerSec: Double = 1.35,
        minTurnIntervalSeconds: TimeInterval = 0.7
    ) {
        self.peakThresholdRadPerSec = peakThresholdRadPerSec
        self.minTurnIntervalSeconds = minTurnIntervalSeconds
    }

    /// ジャイロサンプル列と滑走距離からターンメトリクスを算出する
    public func analyze(gyroSamples: [GyroSample], skiDistanceMeters: Double) -> TurnMetrics {
        let sorted = gyroSamples.sorted { $0.timestamp < $1.timestamp }
        guard sorted.count >= 3 else {
            return TurnMetrics(turnCount: 0, turnsPerKilometer: 0, arcStyle: .medium, consistencyScore: 0)
        }

        // 3点移動平均で高周波ノイズを平滑化
        let smoothed: [Double] = sorted.indices.map { idx in
            let prev = sorted[max(0, idx - 1)].magnitude
            let curr = sorted[idx].magnitude
            let next = sorted[min(sorted.count - 1, idx + 1)].magnitude
            return (prev + curr + next) / 3.0
        }

        var peakTimestamps: [Date] = []
        for idx in 1..<(smoothed.count - 1) {
            let value = smoothed[idx]
            guard value >= peakThresholdRadPerSec,
                  value >= smoothed[idx - 1],
                  value > smoothed[idx + 1] else {
                continue
            }
            let timestamp = sorted[idx].timestamp
            if let lastPeak = peakTimestamps.last,
               timestamp.timeIntervalSince(lastPeak) < minTurnIntervalSeconds {
                continue
            }
            peakTimestamps.append(timestamp)
        }

        let turnCount = peakTimestamps.count
        let distanceKm = max(skiDistanceMeters / 1000.0, 0.05)
        let density = skiDistanceMeters >= 50 ? Double(turnCount) / distanceKm : 0
        let consistency = Self.calculateConsistencyScore(peakTimestamps: peakTimestamps)

        return TurnMetrics(
            turnCount: turnCount,
            turnsPerKilometer: density,
            arcStyle: TurnMetrics.classifyArcStyle(turnsPerKilometer: density),
            consistencyScore: consistency
        )
    }

    /// ターン間隔の変動係数（CV）からリズム安定度（0〜100）を算出する
    private static func calculateConsistencyScore(peakTimestamps: [Date]) -> Double {
        guard peakTimestamps.count >= 3 else {
            return peakTimestamps.isEmpty ? 0 : 70.0
        }

        var intervals: [Double] = []
        for idx in 1..<peakTimestamps.count {
            let dt = peakTimestamps[idx].timestampInterval(since: peakTimestamps[idx - 1])
            // リフト乗車や長い休憩を挟む極端な間隔（15秒超）は除外
            if dt > 0 && dt <= 15.0 {
                intervals.append(dt)
            }
        }
        guard intervals.count >= 2 else { return 70.0 }

        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return 0 }

        let variance = intervals.reduce(0) { acc, val in
            acc + pow(val - mean, 2)
        } / Double(intervals.count)
        let stdDev = sqrt(variance)
        let coefficientOfVariation = stdDev / mean

        // CV が 0 に近いほど 100 点、CV >= 0.8 で 20 点付近へ減衰
        let score = 100.0 - (coefficientOfVariation * 100.0)
        return min(100.0, max(20.0, score))
    }
}

private extension Date {
    func timestampInterval(since other: Date) -> TimeInterval {
        timeIntervalSince(other)
    }
}
