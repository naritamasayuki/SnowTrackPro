import Foundation
import Testing
@testable import SnowTrackCore

@Suite("逐次集計（TrackMetricsAccumulator）テスト")
struct TrackMetricsAccumulatorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func sample(
        _ t: Double,
        lat: Double,
        alt: Double,
        speed: Double,
        hAcc: Double = 5,
        vAcc: Double? = nil,
        sAcc: Double? = nil
    ) -> TrackSample {
        TrackSample(
            timestamp: start.addingTimeInterval(t),
            latitude: lat,
            longitude: 141.1990,
            altitudeMeters: alt,
            speedMetersPerSecond: speed,
            horizontalAccuracyMeters: hAcc,
            verticalAccuracyMeters: vAcc,
            speedAccuracyMetersPerSecond: sAcc
        )
    }

    @Test("±1.2m の高度ノイズだけでは獲得標高差が増えない")
    func altitudeNoiseIsIgnored() {
        var acc = TrackMetricsAccumulator()
        for i in 0..<120 {
            acc.add(sample(
                Double(i),
                lat: 43.0760 + Double(i) * 0.00005,
                alt: 1000 + (i.isMultiple(of: 2) ? 1.2 : -1.2),
                speed: 5.5
            ))
        }
        #expect(acc.summary.verticalDropMeters == 0)
    }

    @Test("verticalAccuracy が無効（負値）の高度は標高差に使わない")
    func invalidVerticalAccuracyIsSkipped() {
        var acc = TrackMetricsAccumulator()
        acc.add(sample(0, lat: 43.0760, alt: 1000, speed: 10, vAcc: 5))
        acc.add(sample(1, lat: 43.0761, alt: 0, speed: 10, vAcc: -1))
        acc.add(sample(2, lat: 43.0762, alt: 990, speed: 10, vAcc: 5))
        #expect(abs(acc.summary.verticalDropMeters - 10) < 0.01)
    }

    @Test("Doppler 速度のスパイク（位置変化と矛盾）は最高速度に採用しない")
    func speedSpikeIsRejected() {
        var acc = TrackMetricsAccumulator()
        for i in 0..<10 {
            let speed = (i == 5) ? 40.0 : 10.0 // 144 km/h のスパイク
            acc.add(sample(
                Double(i),
                lat: 43.0760 + Double(i) * 0.00009,
                alt: 1000 - Double(i),
                speed: speed
            ))
        }
        #expect(acc.summary.maxSpeedKilometersPerHour < 40)
    }

    @Test("speedAccuracy が悪いサンプルは最高速度に採用しない")
    func poorSpeedAccuracyIsRejected() {
        var acc = TrackMetricsAccumulator()
        acc.add(sample(0, lat: 43.0760, alt: 1000, speed: 10, sAcc: 0.5))
        acc.add(sample(1, lat: 43.07609, alt: 999, speed: 15, sAcc: 6.0))
        acc.add(sample(2, lat: 43.07618, alt: 998, speed: 10, sAcc: 0.5))
        #expect(abs(acc.summary.maxSpeedKilometersPerHour - 36) < 0.01)
    }

    @Test("静止中の位置ジッターは距離に加算しない")
    func stationaryJitterAddsNoDistance() {
        var acc = TrackMetricsAccumulator()
        for i in 0..<60 {
            let jitter = i.isMultiple(of: 2) ? 0.00003 : -0.00003 // 約±3.3m
            acc.add(sample(Double(i), lat: 43.0760 + jitter, alt: 1000, speed: 0.2, hAcc: 10))
        }
        #expect(acc.summary.totalDistanceMeters == 0)
    }

    @Test("1m/s の低速移動は刻みが小さくても累積して距離に入る")
    func slowMovementAccumulates() {
        var acc = TrackMetricsAccumulator()
        for i in 0...30 {
            acc.add(sample(Double(i), lat: 43.0760 + Double(i) * 0.000009, alt: 1000, speed: 1.0))
        }
        let distance = acc.summary.totalDistanceMeters
        #expect(distance > 25 && distance <= 31)
    }

    @Test("summarize と逐次集計が同じ結果になる")
    func summarizeMatchesAccumulator() {
        let samples = (0..<50).map { i in
            sample(Double(i), lat: 43.0760 + Double(i) * 0.00009, alt: 1000 - Double(i) * 2, speed: 10)
        }
        var acc = TrackMetricsAccumulator()
        samples.forEach { acc.add($0) }
        #expect(TrackMetricsCalculator().summarize(samples: samples) == acc.summary)
    }
}
