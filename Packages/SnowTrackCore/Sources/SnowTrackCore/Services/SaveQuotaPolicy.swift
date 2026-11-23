import Foundation

/// 年間保存回数の制限およびプロプラン（買い切り）による無制限保存の判定ポリシー
public struct SaveQuotaPolicy: Sendable {
    /// 無料プランで過去1年間（365日以内）に保存できるセッション上限数
    public static let annualFreeSaveLimit: Int = 5

    /// App Store Connect に登録する非消耗型（買い切り）アプリ内課金 商品ID
    public static let proUnlockProductID: String = "com.naritamasayuki.SnowTrackPro.pro.unlimited"

    public init() {}

    /// 基準日時から過去1年間（1年前の同時刻以降）に保存されたセッション数を返す
    public func countSavesInPastYear(
        existingSessionDates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: now) else {
            return existingSessionDates.count
        }
        return existingSessionDates.filter { $0 > oneYearAgo && $0 <= now }.count
    }

    /// 新しいセッションを保存可能かどうかを判定する
    public func canSaveSession(
        existingSessionDates: [Date],
        isPro: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        if isPro {
            return true
        }
        let recentCount = countSavesInPastYear(
            existingSessionDates: existingSessionDates,
            now: now,
            calendar: calendar
        )
        return recentCount < Self.annualFreeSaveLimit
    }

    /// 無料プランの残り保存可能回数（プロプランの場合は nil＝無制限）
    public func remainingFreeSaves(
        existingSessionDates: [Date],
        isPro: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        if isPro {
            return nil
        }
        let recentCount = countSavesInPastYear(
            existingSessionDates: existingSessionDates,
            now: now,
            calendar: calendar
        )
        return max(0, Self.annualFreeSaveLimit - recentCount)
    }
}
