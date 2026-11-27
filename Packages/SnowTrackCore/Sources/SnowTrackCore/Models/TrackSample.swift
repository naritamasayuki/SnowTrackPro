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
    /// 垂直方向の測位精度（メートル）。nil は不明（旧データ・デモ）、負値は高度が無効
    public let verticalAccuracyMeters: Double?
    /// 速度の精度（メートル毎秒）。nil は不明、負値は速度が無効
    public let speedAccuracyMetersPerSecond: Double?

    public init(
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
        speedMetersPerSecond: Double,
        horizontalAccuracyMeters: Double,
        verticalAccuracyMeters: Double? = nil,
        speedAccuracyMetersPerSecond: Double? = nil
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeMeters = altitudeMeters
        self.speedMetersPerSecond = speedMetersPerSecond
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.speedAccuracyMetersPerSecond = speedAccuracyMetersPerSecond
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

    /// 高度が標高差の計算に使える品質か（精度不明の旧データは使用可とする）
    public func hasUsableAltitude(maxVerticalAccuracyMeters: Double = 20.0) -> Bool {
        guard let verticalAccuracyMeters else { return true }
        return verticalAccuracyMeters >= 0 && verticalAccuracyMeters <= maxVerticalAccuracyMeters
    }

    /// Doppler 速度が信頼できるか（速度精度と、直前点からの位置変化による速度との整合を確認）
    public func hasPlausibleSpeed(
        impliedMetersPerSecond: Double,
        maxSpeedAccuracyMetersPerSecond: Double = 2.5
    ) -> Bool {
        guard speedMetersPerSecond >= 0 else { return false }
        if let speedAccuracyMetersPerSecond,
           speedAccuracyMetersPerSecond < 0 || speedAccuracyMetersPerSecond > maxSpeedAccuracyMetersPerSecond {
            return false
        }
        return speedMetersPerSecond <= impliedMetersPerSecond * 1.5 + 3.0
    }
}
