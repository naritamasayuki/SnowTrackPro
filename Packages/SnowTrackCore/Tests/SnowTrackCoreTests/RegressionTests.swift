import Foundation
import Testing
@testable import SnowTrackCore

@Suite("監査修正案の追加回帰テスト")
struct AuditRegressionTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("平地の車移動で高度が±2m揺れても滑走扱いにならない")
    func flatDrivingWithAltitudeNoiseIsNotSkiing() {
        var machine = RunStateMachine()
        for i in 0..<60 {
            machine.ingest(TrackSample(
                timestamp: start.addingTimeInterval(Double(i)),
                latitude: 43.0760 + Double(i) * 0.000225,
                longitude: 141.1990,
                altitudeMeters: 500 + (i.isMultiple(of: 2) ? 2 : -2),
                speedMetersPerSecond: 25,
                horizontalAccuracyMeters: 5
            ))
        }
        #expect(machine.runCount == 0)
        #expect(machine.maxSkiSpeedKmh == 0)
    }

    @Test("先頭サンプルが外れ値でも、以降の正常な軌跡の距離を水増ししない")
    func firstSampleOutlierDoesNotInflateDistance() {
        var acc = TrackMetricsAccumulator()
        acc.add(TrackSample(
            timestamp: start,
            latitude: 43.2000,
            longitude: 141.1990,
            altitudeMeters: 1000,
            speedMetersPerSecond: 10,
            horizontalAccuracyMeters: 5
        ))
        for i in 1...400 {
            acc.add(TrackSample(
                timestamp: start.addingTimeInterval(Double(i)),
                latitude: 43.0760 + Double(i) * 0.00009,
                longitude: 141.1990,
                altitudeMeters: 1000 - Double(i),
                speedMetersPerSecond: 10,
                horizontalAccuracyMeters: 5
            ))
        }
        let d = acc.summary.totalDistanceMeters
        #expect(d > 3_800 && d < 4_100)
    }

    @Test("速度が無効値（-1）のまま静止していても位置ジッターを距離に加算しない")
    func stationaryJitterWithInvalidSpeedAddsNoDistance() {
        var acc = TrackMetricsAccumulator()
        for i in 0..<60 {
            acc.add(TrackSample(
                timestamp: start.addingTimeInterval(Double(i)),
                latitude: 43.0760 + (i.isMultiple(of: 2) ? 0.00005 : -0.00005),
                longitude: 141.1990,
                altitudeMeters: 1000,
                speedMetersPerSecond: -1,
                horizontalAccuracyMeters: 10
            ))
        }
        #expect(acc.summary.totalDistanceMeters == 0)
    }
}
