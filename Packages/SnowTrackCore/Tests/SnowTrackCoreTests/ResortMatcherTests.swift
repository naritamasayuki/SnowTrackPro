import Foundation
import Testing
@testable import SnowTrackCore

@Suite("スキー場自動判定（ResortMatcher）テスト")
struct ResortMatcherTests {
    @Test("バンドル同梱の resorts.json を正常に読み込める")
    func loadBundledCatalog() throws {
        let matcher = try ResortMatcher.loadBundled()
        #expect(matcher.resorts.count >= 10)
    }

    @Test("サッポロテイネ付近の座標で正しくジオフェンシング判定される")
    func matchSapporoTeine() throws {
        let matcher = try ResortMatcher.loadBundled()
        let result = matcher.matchResort(latitude: 43.0770, longitude: 141.2005)
        #expect(result?.resort.id == "sapporo-teine")
        #expect((result?.distanceMeters ?? 9999) < 200)
    }

    @Test("どのスキー場からも遠い座標では nil を返す")
    func matchOutsideAnyResort() throws {
        let matcher = try ResortMatcher.loadBundled()
        // 東京駅付近
        let result = matcher.matchResort(latitude: 35.6812, longitude: 139.7671)
        #expect(result == nil)
    }

    @Test("不正な緯度・経度（範囲外）はクラッシュせず nil を返す")
    func matchInvalidCoordinates() throws {
        let matcher = try ResortMatcher.loadBundled()
        #expect(matcher.matchResort(latitude: 120.0, longitude: 140.0) == nil)
        #expect(matcher.matchResort(latitude: 43.0, longitude: -200.0) == nil)
    }

    @Test("多言語ロケールに応じてスキー場名が切り替わり、未対応言語は英語にフォールバックする")
    func localizedResortName() throws {
        let matcher = try ResortMatcher.loadBundled()
        let teine = try #require(matcher.resorts.first { $0.id == "sapporo-teine" })

        #expect(teine.localizedName(for: Locale(identifier: "ja_JP")) == "サッポロテイネ")
        #expect(teine.localizedName(for: Locale(identifier: "en_US")) == "Sapporo Teine")
        #expect(teine.localizedName(for: Locale(identifier: "zh_Hans_CN")) == "札幌手稻滑雪场")
        #expect(teine.localizedName(for: Locale(identifier: "zh_Hant_TW")) == "札幌手稻滑雪場")
        #expect(teine.localizedName(for: Locale(identifier: "fr_FR")) == "Sapporo Teine")
    }
}
