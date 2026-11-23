import Foundation

/// Amazon おすすめ購入導線のカテゴリ一覧
public enum SnowGearCategory: String, CaseIterable, Identifiable, Sendable {
    /// スキー・スノーボードグッズ（ゴーグル・グローブ・ワックス等）
    case skiSnowboardGear
    /// リフト券・スキー場チケット関連
    case liftTickets
    /// 宿泊・ゲレンデ旅行グッズ
    case lodgingAndTravel
    /// ヘルメット・プロテクター等の安全ギア
    case protectorsAndSafety

    public var id: String { rawValue }

    /// 日本（Amazon.co.jp）向け検索キーワード
    public var japaneseKeyword: String {
        switch self {
        case .skiSnowboardGear:
            return "スキー スノーボード グッズ ゴーグル グローブ ワックス"
        case .liftTickets:
            return "スキー場 リフト券"
        case .lodgingAndTravel:
            return "スキー場 宿泊券 旅行 ホテル 予約 ガイド"
        case .protectorsAndSafety:
            return "スノーボード プロテクター ヘルメット"
        }
    }

    /// 海外（Amazon.com）向け検索キーワード
    public var internationalKeyword: String {
        switch self {
        case .skiSnowboardGear:
            return "ski snowboard gear goggles gloves wax"
        case .liftTickets:
            return "ski pass holder lift ticket"
        case .lodgingAndTravel:
            return "ski trip travel bag boot bag winter lodge"
        case .protectorsAndSafety:
            return "ski snowboard helmet impact protector"
        }
    }
}

/// Amazon アソシエイト（物販アフィリエイト）の安全な検索 URL ビルダー
public struct AmazonAffiliateLinkBuilder: Sendable {
    /// 共通 Amazon アソシエイト ID（Amazon.co.jp）
    public static let japanAssociateTag = "shirokumacamp-22"

    public init() {}

    /// 日本向け Amazon.co.jp を使用すべきロケールかを判定する
    public func isJapanLocale(_ locale: Locale) -> Bool {
        if locale.region?.identifier.uppercased() == "JP" {
            return true
        }
        return locale.language.languageCode?.identifier == "ja"
    }

    /// カテゴリとロケールから安全な Amazon 検索 URL を生成する
    public func buildSearchURL(for category: SnowGearCategory, locale: Locale = .current) -> URL? {
        let keyword = isJapanLocale(locale) ? category.japaneseKeyword : category.internationalKeyword
        return buildSearchURL(keyword: keyword, locale: locale)
    }

    /// 任意の検索キーワードとロケールから `URLComponents` で安全な Amazon 検索 URL を生成する
    public func buildSearchURL(keyword: String, locale: Locale = .current) -> URL? {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.path = "/s"

        if isJapanLocale(locale) {
            components.host = "www.amazon.co.jp"
            components.queryItems = [
                URLQueryItem(name: "k", value: trimmed),
                URLQueryItem(name: "tag", value: Self.japanAssociateTag)
            ]
        } else {
            components.host = "www.amazon.com"
            components.queryItems = [
                URLQueryItem(name: "k", value: trimmed)
            ]
        }
        return components.url
    }
}
