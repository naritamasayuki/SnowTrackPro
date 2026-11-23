import Foundation
import Testing
@testable import SnowTrackCore

@Suite("転倒推定・急ブレーキ推定（TrackEventDetector）テスト")
struct TrackEventDetectorTests {
    private let detector = TrackEventDetector()

    @Test("滑走中からの急停止＋5秒以上の静止で転倒推定（possibleFall）を検出する")
    func detectsPossibleFall() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let samples: [TrackSample] = [
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 950, speedMetersPerSecond: 10.0, horizontalAccuracyMeters: 5), // 36 km/h
            TrackSample(timestamp: start.addingTimeInterval(2), latitude: 43.0762, longitude: 141.1991, altitudeMeters: 945, speedMetersPerSecond: 0.5, horizontalAccuracyMeters: 5), // 1.8 km/h 急停止
            TrackSample(timestamp: start.addingTimeInterval(5), latitude: 43.07621, longitude: 141.19911, altitudeMeters: 945, speedMetersPerSecond: 0.3, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(9), latitude: 43.07621, longitude: 141.19912, altitudeMeters: 945, speedMetersPerSecond: 0.2, horizontalAccuracyMeters: 5)
        ]

        let events = detector.detectEvents(samples: samples)
        #expect(events.count == 1)
        #expect(events.first?.kind == .possibleFall)
    }

    @Test("高速域からの急減速後に滑走継続した場合は急ブレーキ（hardBraking）を検出する")
    func detectsHardBraking() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let samples: [TrackSample] = [
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 950, speedMetersPerSecond: 14.0, horizontalAccuracyMeters: 5), // 50.4 km/h
            TrackSample(timestamp: start.addingTimeInterval(3), latitude: 43.0763, longitude: 141.1992, altitudeMeters: 942, speedMetersPerSecond: 3.0, horizontalAccuracyMeters: 5), // 10.8 km/h (減速 3.67 m/s^2)
            TrackSample(timestamp: start.addingTimeInterval(6), latitude: 43.0766, longitude: 141.1994, altitudeMeters: 934, speedMetersPerSecond: 8.0, horizontalAccuracyMeters: 5) // 再加速
        ]

        let events = detector.detectEvents(samples: samples)
        #expect(events.count == 1)
        #expect(events.first?.kind == .hardBraking)
        #expect((events.first?.decelerationG ?? 0) > 0.3)
    }

    @Test("緩やかな減速ではイベントを誤検知しない")
    func ignoresGentleDeceleration() {
        let start = Date(timeIntervalSince1970: 1_750_000_000)
        let samples: [TrackSample] = [
            TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 950, speedMetersPerSecond: 10.0, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(8), latitude: 43.0766, longitude: 141.1994, altitudeMeters: 935, speedMetersPerSecond: 6.0, horizontalAccuracyMeters: 5),
            TrackSample(timestamp: start.addingTimeInterval(16), latitude: 43.0770, longitude: 141.1997, altitudeMeters: 925, speedMetersPerSecond: 3.0, horizontalAccuracyMeters: 5)
        ]

        let events = detector.detectEvents(samples: samples)
        #expect(events.isEmpty)
    }
}
