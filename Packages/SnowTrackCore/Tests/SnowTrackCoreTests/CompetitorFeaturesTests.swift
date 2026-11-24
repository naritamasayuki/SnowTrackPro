import Foundation
import Testing
@testable import SnowTrackCore

@Suite("競合キラー機能（斜度解析・GPX出力・32スキー場）テスト")
struct CompetitorFeaturesTests {
    @Test("国内主要スキー場を含む30箇所以上のマスターデータが読み込め、白馬五竜やトマムも判定できる")
    func expandedResortsCatalog() throws {
        let matcher = try ResortMatcher.loadBundled()
        #expect(matcher.resorts.count >= 30)

        let tomamu = matcher.matchResort(latitude: 43.0635, longitude: 142.6320)
        #expect(tomamu?.resort.id == "hoshino-tomamu")
        #expect(tomamu?.resort.localizedName(for: Locale(identifier: "ja_JP")) == "星野リゾート トマム")
    }

    @Test("斜度計算（SlopePitchCalculator）が下降区間の最大斜度と平均斜度を正確に算出する")
    func calculatesSlopePitch() {
        let calculator = SlopePitchCalculator()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        // 緯度 0.0009度 ≒ 約 100m 水平移動で 57.7m 下降 → arctan(57.7 / 100) ≒ 約 30°
        let samples = [
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 1000, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(10), latitude: 43.0769, longitude: 141.1990, altitudeMeters: 942.3, speedMetersPerSecond: 12, horizontalAccuracyMeters: 5)
        ]

        let summary = calculator.analyze(samples: samples)
        #expect(summary.maxPitchDegrees > 27.0 && summary.maxPitchDegrees < 33.0)
        #expect(summary.averagePitchDegrees > 27.0 && summary.averagePitchDegrees < 33.0)
    }

    @Test("GPXExporter が有効な GPX 1.1 XML を生成し特殊文字をエスケープする")
    func exportsValidGPX() {
        let exporter = GPXExporter()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let samples = [
            TrackSample(timestamp: start, latitude: 43.0764, longitude: 141.1997, altitudeMeters: 980, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(10), latitude: 43.0774, longitude: 141.2007, altitudeMeters: 940, speedMetersPerSecond: 12, horizontalAccuracyMeters: 5)
        ]

        let xml = exporter.exportGPX(trackName: "白馬五竜 & 47 <Test>", startedAt: start, samples: samples)
        #expect(xml.contains(#"<gpx version="1.1""#))
        #expect(xml.contains("白馬五竜 &amp; 47 &lt;Test&gt;"))
        #expect(xml.contains(#"<trkpt lat="43.076400" lon="141.199700">"#))
        #expect(xml.contains("<ele>980.0</ele>"))
        #expect(xml.contains("</gpx>"))
    }
}
