import Foundation

/// GPSから取得した単一の軌跡サンプル
public struct TrackSample: Codable, Equatable, Hashable, Sendable {
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    /// 標高（メートル）
    public let altitudeMeters: Double
    /// 移動速度（メートル毎秒）。負値は無効値として扱う
    public let speedMetersPerSecond: Double
    /// 水平方向の測位精度（メートル）。負値は無効値として扱う
    public let horizontalAccuracyMeters: Double

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
        speedMetersPerSecond: Double,
        horizontalAccuracyMeters: Double
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
    }

    /// 速度（km/h）を返す。無効値の場合は 0.0
    public var speedKilometersPerHour: Double {
        max(0, speedMetersPerSecond) * 3.6
    }

    /// GPSサンプルが統計計算に利用可能な品質かを判定する
    public func isValid(maxAccuracyMeters: Double = 50.0) -> Bool {
        guard horizontalAccuracyMeters >= 0, horizontalAccuracyMeters <= maxAccuracyMeters else {
            return false
        }
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else {
            return false
        }
        return true
    }
}
