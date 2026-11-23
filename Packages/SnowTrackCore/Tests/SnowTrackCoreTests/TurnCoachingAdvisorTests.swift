import Foundation
import Testing
@testable import SnowTrackCore

@Suite("ターン解析・過去比較コーチング（TurnAnalyzer & TurnCoachingAdvisor）テスト")
struct TurnCoachingAdvisorTests {
    @Test("3軸ジャイロの周期波形からポケット向き非依存でターン数と高いリズム安定度を検出できる")
    func detectPeriodicTurnsFromGyro() {
        let analyzer = TurnAnalyzer(peakThresholdRadPerSec: 1.3, minTurnIntervalSeconds: 0.7)
        let start = Date(timeIntervalSince1970: 1_750_000_000)

        // 2秒ごとに規則的なターンピークが発生する 20Hz 波形（10秒間 = 約5ターン）
        var samples: [GyroSample] = []
        for step in 0...200 {
            let t = Double(step) * 0.05
            // sin^2 で 2秒ごとにピーク 2.0 rad/s を生成
            let wave = abs(sin(t * .pi / 2.0)) * 2.0
            // 3軸に分散させて端末の傾きを模擬
            samples.append(GyroSample(
                timestamp: start.addingTimeInterval(t),
                x: wave * 0.6,
                y: wave * 0.6,
                z: wave * 0.529
            ))
        }

        let metrics = analyzer.analyze(gyroSamples: samples, skiDistanceMeters: 200)
        #expect(metrics.turnCount >= 4 && metrics.turnCount <= 6)
        #expect(metrics.consistencyScore >= 80.0)
        #expect(metrics.turnsPerKilometer > 15.0)
    }

    @Test("初回セッション（履歴なし）では initialBaseline アドバイスを返す")
    func initialBaselineAdvice() {
        let advisor = TurnCoachingAdvisor()
        let current = SessionTurnSnapshot(
            turnCount: 30,
            turnsPerKilometer: 28,
            consistencyScore: 76,
            maxSpeedKilometersPerHour: 48
        )

        let report = advisor.evaluate(current: current, previousSessions: [])
        #expect(report.adviceKind == .initialBaseline)
        #expect(report.comparedSessionCount == 0)
        #expect(report.turnDensityDeltaPercent == nil)
    }

    @Test("過去平均よりリズム安定度が大きく向上した場合は improvedRhythm を返す")
    func improvedRhythmAdvice() {
        let advisor = TurnCoachingAdvisor()
        let history = [
            SessionTurnSnapshot(turnCount: 25, turnsPerKilometer: 25, consistencyScore: 68, maxSpeedKilometersPerHour: 45),
            SessionTurnSnapshot(turnCount: 28, turnsPerKilometer: 26, consistencyScore: 70, maxSpeedKilometersPerHour: 47)
        ]
        let current = SessionTurnSnapshot(turnCount: 27, turnsPerKilometer: 26, consistencyScore: 84, maxSpeedKilometersPerHour: 48)

        let report = advisor.evaluate(current: current, previousSessions: history)
        #expect(report.adviceKind == .improvedRhythm)
        #expect((report.consistencyDeltaPoints ?? 0) >= 14.0)
    }

    @Test("過去平均より細かい切り返しが増えた場合は sharperShortTurns を返す")
    func sharperShortTurnsAdvice() {
        let advisor = TurnCoachingAdvisor()
        let history = [
            SessionTurnSnapshot(turnCount: 20, turnsPerKilometer: 20, consistencyScore: 78, maxSpeedKilometersPerHour: 50)
        ]
        let current = SessionTurnSnapshot(turnCount: 40, turnsPerKilometer: 38, consistencyScore: 79, maxSpeedKilometersPerHour: 46)

        let report = advisor.evaluate(current: current, previousSessions: history)
        #expect(report.adviceKind == .sharperShortTurns)
        #expect(report.currentArcStyle == .short)
        #expect((report.turnDensityDeltaPercent ?? 0) > 50.0)
    }

    @Test("過去平均より大きな弧で高速化した場合は fasterLongTurns を返す")
    func fasterLongTurnsAdvice() {
        let advisor = TurnCoachingAdvisor()
        let history = [
            SessionTurnSnapshot(turnCount: 30, turnsPerKilometer: 30, consistencyScore: 80, maxSpeedKilometersPerHour: 48)
        ]
        let current = SessionTurnSnapshot(turnCount: 14, turnsPerKilometer: 14, consistencyScore: 81, maxSpeedKilometersPerHour: 62)

        let report = advisor.evaluate(current: current, previousSessions: history)
        #expect(report.adviceKind == .fasterLongTurns)
        #expect(report.currentArcStyle == .long)
    }
}
