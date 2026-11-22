import Testing
@testable import SnowTrackCore

@Suite("サブスクリプション機能ゲート（EntitlementPolicy）テスト")
struct EntitlementPolicyTests {
    private let policy = EntitlementPolicy()

    @Test("無料プランではPro機能にアクセスできず、Proプランでは全機能にアクセスできる")
    func featureGating() {
        for feature in ProFeature.allCases {
            #expect(policy.canAccess(feature, tier: .free) == false)
            #expect(policy.canAccess(feature, tier: .pro) == true)
        }
    }

    @Test("無料プランの履歴閲覧上限が正しく適用される")
    func historyLimit() {
        #expect(policy.canViewHistoryItem(at: 0, tier: .free) == true)
        #expect(policy.canViewHistoryItem(at: EntitlementPolicy.freeHistoryLimit - 1, tier: .free) == true)
        #expect(policy.canViewHistoryItem(at: EntitlementPolicy.freeHistoryLimit, tier: .free) == false)
        #expect(policy.canViewHistoryItem(at: -1, tier: .pro) == false)
        #expect(policy.canViewHistoryItem(at: 100, tier: .pro) == true)
    }
}
