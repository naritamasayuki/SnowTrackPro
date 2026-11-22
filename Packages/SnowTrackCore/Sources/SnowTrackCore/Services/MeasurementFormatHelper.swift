import Foundation

/// ロケール（メートル法 / ヤード・ポンド法）に追従して滑走数値をフォーマットするヘルパー
public struct MeasurementFormatHelper: Sendable {
    public let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// ヤード・ポンド法（米国等）を使用するロケールか判定する
    public var usesImperialUnits: Bool {
        locale.measurementSystem == .us || locale.measurementSystem == .uk
    }

    /// 速度（km/h入力）をロケールに応じた数値と単位文字列へ変換する
    public func formattedSpeed(kilometersPerHour: Double) -> (value: String, unit: String) {
        let clamped = max(0, kilometersPerHour)
        if usesImperialUnits {
            let mph = clamped * 0.621371
            return (String(format: "%.1f", mph), "mph")
        } else {
            return (String(format: "%.1f", clamped), "km/h")
        }
    }

    /// 距離（メートル入力）をロケールに応じた文字列へ変換する
    public func formattedDistance(meters: Double) -> String {
        let clamped = max(0, meters)
        if usesImperialUnits {
            let miles = clamped / 1609.344
            return String(format: "%.2f mi", miles)
        } else {
            let kilometers = clamped / 1000.0
            return String(format: "%.2f km", kilometers)
        }
    }

    /// 標高差（メートル入力）をロケールに応じた文字列へ変換する
    public func formattedElevation(meters: Double) -> String {
        let clamped = max(0, meters)
        if usesImperialUnits {
            let feet = clamped * 3.28084
            return String(format: "%.0f ft", feet)
        } else {
            return String(format: "%.0f m", clamped)
        }
    }

    /// 経過時間（秒）を HH:MM:SS 形式でフォーマットする
    public func formattedDuration(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}
