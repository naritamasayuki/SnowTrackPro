import Foundation

/// サブスクリプションの契約ティア
public enum SubscriptionTier: String, Codable, Equatable, Sendable {
    case free
    case pro
}

/// アプリ内の機能ゲート対象となるPro機能一覧
public enum ProFeature: String, CaseIterable, Equatable, Identifiable, Sendable {
    /// 速度ヒートマップ表示
    case speedHeatmap
    /// ターン数・ターン弧の深掘り解析（Phase 2）
    case turnAnalytics
    /// 停止までの制動距離・減速G計測（Phase 2）
    case brakingDistanceAnalytics
    /// 無制限の滑走履歴保存・閲覧
    case unlimitedHistory
    /// 広告非表示
    case adFree
    /// SNSシェア用リザルトカード（透かしなし）
    case shareCardExport

    public var id: String { rawValue }
}

/// フリーミアム＋サブスクリプションの機能制限および商品IDを管理するポリシー
public struct EntitlementPolicy: Sendable {
    /// 無料プランで閲覧できる直近セッション数の上限
    public static let freeHistoryLimit: Int = 5

    /// App Store Connect に登録する StoreKit 2 サブスクリプション商品ID
    public static let monthlyProProductID = "com.snowtrackpro.subscription.pro.monthly"
    public static let yearlyProProductID = "com.snowtrackpro.subscription.pro.yearly"

    public static var allProductIDs: [String] {
        [monthlyProProductID, yearlyProProductID]
    }

    public init() {}

    /// 指定された機能が現在の契約ティアで利用可能かを判定する
    public func canAccess(_ feature: ProFeature, tier: SubscriptionTier) -> Bool {
        switch tier {
        case .pro:
            return true
        case .free:
            return false
        }
    }

    /// 指定されたインデックス（新しい順 0始まり）の履歴セッションが閲覧可能かを判定する
    public func canViewHistoryItem(at index: Int, tier: SubscriptionTier) -> Bool {
        guard index >= 0 else { return false }
        switch tier {
        case .pro:
            return true
        case .free:
            return index < Self.freeHistoryLimit
        }
    }
}
