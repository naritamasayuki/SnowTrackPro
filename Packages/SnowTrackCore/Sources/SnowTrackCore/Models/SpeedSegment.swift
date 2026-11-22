import Foundation

/// 滑走ラインのヒートマップ描画用の速度帯域
public enum SpeedBand: String, Codable, Equatable, Hashable, Sendable {
    /// 低速（例: 20 km/h 未満）— 青
    case low
    /// 中速（例: 20〜45 km/h）— 黄
    case medium
    /// 高速（例: 45 km/h 以上）— 赤
    case high

    /// 速度（km/h）から対応する速度帯域を分類する
    public static func from(speedKmh: Double) -> SpeedBand {
        switch speedKmh {
        case ..<20.0:
            return .low
        case 20.0..<45.0:
            return .medium
        default:
            return .high
        }
    }
}

/// 地図上に描画するための2点間セグメント
public struct SpeedSegment: Equatable, Hashable, Identifiable, Sendable {
    public let id: Int
    public let startLatitude: Double
    public let startLongitude: Double
    public let endLatitude: Double
    public let endLongitude: Double
    public let speedKilometersPerHour: Double
    public let band: SpeedBand

    public init(
        id: Int,
        startLatitude: Double,
        startLongitude: Double,
        endLatitude: Double,
        endLongitude: Double,
        speedKilometersPerHour: Double
    ) {
        self.id = id
        self.startLatitude = startLatitude
        self.startLongitude = startLongitude
        self.endLatitude = endLatitude
        self.endLongitude = endLongitude
        self.speedKilometersPerHour = speedKilometersPerHour
        self.band = SpeedBand.from(speedKmh: speedKilometersPerHour)
    }
}
