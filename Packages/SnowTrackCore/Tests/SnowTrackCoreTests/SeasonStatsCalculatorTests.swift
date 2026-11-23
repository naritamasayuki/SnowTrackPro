import Foundation
import Testing
@testable import SnowTrackCore

@Suite("シーズン累計＆自己ベスト（SeasonStatsCalculator）テスト")
struct SeasonStatsCalculatorTests {
    private let calculator = SeasonStatsCalculator()

    @Test("複数セッションから累計距離・標高差・自己最高速度・訪問スキー場数を正確に集計する")
    func summarizeSeason() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let sessions = [
            SeasonSessionInput(date: now, resortID: "sapporo-teine", totalDistanceMeters: 12_000, verticalDropMeters: 2_100, maxSpeedKilometersPerHour: 58.5, runCount: 6, turnCount: 180),
            SeasonSessionInput(date: now.addingTimeInterval(-86_400), resortID: "niseko-grand-hirafu", totalDistanceMeters: 20_500, verticalDropMeters: 3_400, maxSpeedKilometersPerHour: 67.2, runCount: 10, turnCount: 310),
            SeasonSessionInput(date: now.addingTimeInterval(-172_800), resortID: "sapporo-teine", totalDistanceMeters: 15_000, verticalDropMeters: 2_500, maxSpeedKilometersPerHour: 61.0, runCount: 8, turnCount: 220)
        ]

        let summary = calculator.summarize(sessions: sessions)
        #expect(summary.sessionCount == 3)
        #expect(summary.totalDistanceMeters == 47_500)
        #expect(summary.totalVerticalDropMeters == 8_000)
        #expect(summary.personalBestSpeedKmh == 67.2)
        #expect(summary.totalRuns == 24)
        #expect(summary.totalTurns == 710)
        #expect(summary.uniqueResortCount == 2)
    }

    @Test("自己最高速度の更新判定が正しく動作する")
    func personalBestSpeedCheck() {
        #expect(calculator.isNewPersonalBestSpeed(currentMaxSpeedKmh: 65.0, previousMaxSpeedsKmh: [55.0, 62.0]) == true)
        #expect(calculator.isNewPersonalBestSpeed(currentMaxSpeedKmh: 60.0, previousMaxSpeedsKmh: [55.0, 62.0]) == false)
        #expect(calculator.isNewPersonalBestSpeed(currentMaxSpeedKmh: 3.0, previousMaxSpeedsKmh: []) == false)
    }

    @Test("気圧計の相対高度がGPS高度のノイズより優先されてリフト判定される")
    func barometerOverridesNoisyGPSAltitude() {
        var machine = RunStateMachine()
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        // GPS高度は逆に下がっているノイズだが、気圧計は +10m 上昇している
        machine.ingest(
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 900, speedMetersPerSecond: 4.0, horizontalAccuracyMeters: 10),
            barometerRelativeAltitudeMeters: 0.0
        )
        let state = machine.ingest(
            TrackSample(timestamp: start.addingTimeInterval(20), latitude: 43.0768, longitude: 141.1990, altitudeMeters: 895, speedMetersPerSecond: 4.0, horizontalAccuracyMeters: 10),
            barometerRelativeAltitudeMeters: 12.0
        )
        #expect(state == .ridingLift)
    }
}
