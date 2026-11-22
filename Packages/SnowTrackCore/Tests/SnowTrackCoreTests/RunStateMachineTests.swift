import Foundation
import Testing
@testable import SnowTrackCore

@Suite("滑走・リフト・休憩ステートマシン（RunStateMachine）テスト")
struct RunStateMachineTests {
    @Test("滑走 -> リフト -> 滑走の遷移でリフト距離を除外し、滑走本数を2本としてカウントする")
    func skiingLiftSkiingSequence() {
        var machine = RunStateMachine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        // 1本目の滑走（下降・時速36km）
        machine.ingest(TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 1000, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5))
        let state1 = machine.ingest(TrackSample(timestamp: start.addingTimeInterval(10), latitude: 43.0769, longitude: 141.1990, altitudeMeters: 970, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5))
        #expect(state1 == .skiing)
        #expect(machine.runCount == 1)
        let firstRunDistance = machine.pureSkiDistanceMeters
        #expect(firstRunDistance > 80)

        // リフト乗車（上昇・時速14.4km）
        let liftState = machine.ingest(TrackSample(timestamp: start.addingTimeInterval(40), latitude: 43.0760, longitude: 141.1990, altitudeMeters: 1000, speedMetersPerSecond: 4, horizontalAccuracyMeters: 5))
        #expect(liftState == .ridingLift)
        // リフト乗車中は純粋滑走距離が増えないこと
        #expect(machine.pureSkiDistanceMeters == firstRunDistance)

        // 2本目の滑走
        let state2 = machine.ingest(TrackSample(timestamp: start.addingTimeInterval(50), latitude: 43.0769, longitude: 141.1990, altitudeMeters: 970, speedMetersPerSecond: 11, horizontalAccuracyMeters: 5))
        #expect(state2 == .skiing)
        #expect(machine.runCount == 2)
        #expect(machine.pureSkiDistanceMeters > firstRunDistance)

        // 停止（休憩）
        let restState = machine.ingest(TrackSample(timestamp: start.addingTimeInterval(60), latitude: 43.0769, longitude: 141.1990, altitudeMeters: 970, speedMetersPerSecond: 0.2, horizontalAccuracyMeters: 5))
        #expect(restState == .resting)
    }

    @Test("reset で全状態が初期化される")
    func resetClearsState() {
        var machine = RunStateMachine()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        machine.ingest(TrackSample(timestamp: start, latitude: 43.0760, longitude: 141.1990, altitudeMeters: 1000, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5))
        machine.ingest(TrackSample(timestamp: start.addingTimeInterval(10), latitude: 43.0769, longitude: 141.1990, altitudeMeters: 970, speedMetersPerSecond: 10, horizontalAccuracyMeters: 5))
        #expect(machine.runCount == 1)

        machine.reset()
        #expect(machine.currentState == .resting)
        #expect(machine.runCount == 0)
        #expect(machine.pureSkiDistanceMeters == 0)
        #expect(machine.pureSkiDurationSeconds == 0)
    }
}
