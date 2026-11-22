import Foundation
import Testing
@testable import SnowTrackCore

@Suite("滑走メトリクス計算（TrackMetricsCalculator）テスト")
struct TrackMetricsCalculatorTests {
    private let calculator = TrackMetricsCalculator()

    @Test("空配列ではゼロ値のサマリーを返す")
    func emptySamples() {
        let summary = calculator.summarize(samples: [])
        #expect(summary.totalDistanceMeters == 0)
        #expect(summary.maxSpeedKilometersPerHour == 0)
        #expect(summary.verticalDropMeters == 0)
        #expect(summary.elapsedSeconds == 0)
    }

    @Test("正常な滑走軌跡から距離・最高速度・標高差を正確に算出できる")
    func normalSkiDescent() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let samples: [TrackSample] = [
            TrackSample(
                timestamp: start,
                latitude: 43.0764,
                longitude: 141.1997,
                altitudeMeters: 1000,
                speedMetersPerSecond: 10.0, // 36 km/h
                horizontalAccuracyMeters: 5.0
            ),
            TrackSample(
                timestamp: start.addingTimeInterval(10),
                latitude: 43.0774,
                longitude: 141.1997,
                altitudeMeters: 970,
                speedMetersPerSecond: 15.0, // 54 km/h
                horizontalAccuracyMeters: 5.0
            ),
            TrackSample(
                timestamp: start.addingTimeInterval(20),
                latitude: 43.0784,
                longitude: 141.1997,
                altitudeMeters: 940,
                speedMetersPerSecond: 12.0, // 43.2 km/h
                horizontalAccuracyMeters: 5.0
            )
        ]

        let summary = calculator.summarize(samples: samples)
        #expect(summary.totalDistanceMeters > 200)
        #expect(summary.totalDistanceMeters < 240)
        #expect(abs(summary.maxSpeedKilometersPerHour - 54.0) < 0.01)
        #expect(abs(summary.verticalDropMeters - 60.0) < 0.01)
        #expect(summary.elapsedSeconds == 20)
    }

    @Test("精度不良サンプルとGPSスパイク（非現実的な速度）を除外する")
    func filtersInaccurateAndSpikeSamples() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let samples: [TrackSample] = [
            TrackSample(
                timestamp: start,
                latitude: 43.0764,
                longitude: 141.1997,
                altitudeMeters: 1000,
                speedMetersPerSecond: 8.0,
                horizontalAccuracyMeters: 5.0
            ),
            // 水平精度 120m（除外対象）
            TrackSample(
                timestamp: start.addingTimeInterval(5),
                latitude: 43.0800,
                longitude: 141.2050,
                altitudeMeters: 900,
                speedMetersPerSecond: 20.0,
                horizontalAccuracyMeters: 120.0
            ),
            // 1秒で数kmワープするGPSスパイク（除外対象）
            TrackSample(
                timestamp: start.addingTimeInterval(6),
                latitude: 43.2000,
                longitude: 141.4000,
                altitudeMeters: 500,
                speedMetersPerSecond: 100.0, // 360 km/h
                horizontalAccuracyMeters: 8.0
            )
        ]

        let summary = calculator.summarize(samples: samples)
        #expect(summary.maxSpeedKilometersPerHour < 30.0)
        #expect(summary.totalDistanceMeters == 0)
    }

    @Test("速度に応じたヒートマップ帯域（low/medium/high）が正しく割り当てられる")
    func speedSegmentsClassification() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let samples: [TrackSample] = [
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 1000, speedMetersPerSecond: 4.0, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(5), latitude: 43.0762, longitude: 141.1990, altitudeMeters: 995, speedMetersPerSecond: 4.0, horizontalAccuracyMeters: 5), // 14.4 km/h -> low
            TrackSample(timestamp: start.addingTimeInterval(10), latitude: 43.0766, longitude: 141.1990, altitudeMeters: 985, speedMetersPerSecond: 9.0, horizontalAccuracyMeters: 5), // 32.4 km/h -> medium
            TrackSample(timestamp: start.addingTimeInterval(15), latitude: 43.0772, longitude: 141.1990, altitudeMeters: 965, speedMetersPerSecond: 15.0, horizontalAccuracyMeters: 5) // 54.0 km/h -> high
        ]

        let segments = calculator.buildSpeedSegments(samples: samples)
        #expect(segments.count == 3)
        #expect(segments[0].band == .low)
        #expect(segments[1].band == .medium)
        #expect(segments[2].band == .high)
    }
}
