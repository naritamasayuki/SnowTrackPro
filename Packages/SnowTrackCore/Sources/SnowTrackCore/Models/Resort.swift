import Foundation

/// オフライン同梱されるスキー場のマスターデータモデル
public struct Resort: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    /// 言語コード（例: "ja", "en", "zh-Hans", "zh-Hant"）をキーとした多言語名称マップ
    public let names: [String: String]
    public let countryCode: String
    public let latitude: Double
    public let longitude: Double
    /// ジオフェンシング判定の有効半径（メートル）
    public let radiusMeters: Double
    public let baseElevationMeters: Double
    public let summitElevationMeters: Double

    public init(
        id: String,
        names: [String: String],
        countryCode: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        baseElevationMeters: Double,
        summitElevationMeters: Double
    ) {
        self.id = id
        self.names = names
        self.countryCode = countryCode
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.baseElevationMeters = baseElevationMeters
        self.summitElevationMeters = summitElevationMeters
    }

    /// 指定されたロケールに最適なスキー場名称を返す（未対応言語は英語へフォールバック）
    public func localizedName(for locale: Locale = .current) -> String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        let scriptCode = locale.language.script?.identifier

        if let scriptCode {
            let compoundKey = "\(languageCode)-\(scriptCode)"
            if let exact = names[compoundKey] {
                return exact
            }
        }

        if let exactLanguage = names[languageCode] {
            return exactLanguage
        }

        // 中国語の地域コードからのフォールバック判定
        if languageCode == "zh" {
            let region = locale.region?.identifier ?? ""
            if ["TW", "HK", "MO"].contains(region), let traditional = names["zh-Hant"] {
                return traditional
            }
            if let simplified = names["zh-Hans"] {
                return simplified
            }
        }

        return names["en"] ?? names.values.first ?? id
    }
}
