import Foundation
import Testing
@testable import SnowTrackCore

@Suite("Amazon アソシエイト URL 生成（AmazonAffiliateLinkBuilder）テスト")
struct AmazonAffiliateLinkBuilderTests {
    private let builder = AmazonAffiliateLinkBuilder()

    @Test("日本ロケールでは amazon.co.jp と共通アソシエイトID（shirokumacamp-22）が付与される")
    func japanAffiliateURL() throws {
        let jaLocale = Locale(identifier: "ja_JP")
        for category in SnowGearCategory.allCases {
            let url = try #require(builder.buildSearchURL(for: category, locale: jaLocale))
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(components.scheme == "https")
            #expect(components.host == "www.amazon.co.jp")
            #expect(components.path == "/s")
            #expect(components.queryItems?.first(where: { $0.name == "tag" })?.value == "shirokumacamp-22")
            #expect(components.queryItems?.first(where: { $0.name == "k" })?.value == category.japaneseKeyword)
        }
    }

    @Test("海外ロケールでは amazon.com の安全な検索URLを生成し日本用タグを付与しない")
    func internationalURL() throws {
        let usLocale = Locale(identifier: "en_US")
        let url = try #require(builder.buildSearchURL(for: .skiSnowboardGear, locale: usLocale))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "www.amazon.com")
        #expect(components.queryItems?.first(where: { $0.name == "tag" }) == nil)
        #expect(components.queryItems?.first(where: { $0.name == "k" })?.value == SnowGearCategory.skiSnowboardGear.internationalKeyword)
    }

    @Test("空キーワードの場合は nil を返す")
    func emptyKeywordReturnsNil() {
        #expect(builder.buildSearchURL(keyword: "   ", locale: Locale(identifier: "ja_JP")) == nil)
    }
}
