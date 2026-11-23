import Foundation
import Testing
@testable import SnowTrackCore

@Suite("年間保存枠・プロプラン判定（SaveQuotaPolicy）テスト")
struct SaveQuotaPolicyTests {
    private let policy = SaveQuotaPolicy()
    private let calendar = Calendar(identifier: .gregorian)

    @Test("無料プランは過去1年間で5回未満なら保存でき、5回に達すると保存不可になる")
    func freeAnnualLimit() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let fourDates = (1...4).map { now.addingTimeInterval(-Double($0) * 86_400) }
        let fiveDates = (1...5).map { now.addingTimeInterval(-Double($0) * 86_400) }

        #expect(policy.canSaveSession(existingSessionDates: fourDates, isPro: false, now: now, calendar: calendar) == true)
        #expect(policy.remainingFreeSaves(existingSessionDates: fourDates, isPro: false, now: now, calendar: calendar) == 1)

        #expect(policy.canSaveSession(existingSessionDates: fiveDates, isPro: false, now: now, calendar: calendar) == false)
        #expect(policy.remainingFreeSaves(existingSessionDates: fiveDates, isPro: false, now: now, calendar: calendar) == 0)
    }

    @Test("1年以上前の保存履歴はカウント対象外となり、再び保存可能になる")
    func olderThanOneYearDoesNotCount() throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let overOneYearAgo = try #require(calendar.date(byAdding: .day, value: -370, to: now))
        let recentFour = (1...4).map { now.addingTimeInterval(-Double($0) * 86_400) }
        let dates = recentFour + [overOneYearAgo, overOneYearAgo]

        #expect(policy.countSavesInPastYear(existingSessionDates: dates, now: now, calendar: calendar) == 4)
        #expect(policy.canSaveSession(existingSessionDates: dates, isPro: false, now: now, calendar: calendar) == true)
        #expect(policy.remainingFreeSaves(existingSessionDates: dates, isPro: false, now: now, calendar: calendar) == 1)
    }

    @Test("プロプラン（買い切り）は無制限に保存でき、残り回数は nil を返す")
    func proUnlimitedSaves() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let twentyDates = (1...20).map { now.addingTimeInterval(-Double($0) * 86_400) }

        #expect(policy.canSaveSession(existingSessionDates: twentyDates, isPro: true, now: now, calendar: calendar) == true)
        #expect(policy.remainingFreeSaves(existingSessionDates: twentyDates, isPro: true, now: now, calendar: calendar) == nil)
    }
}
