import Foundation
import SnowTrackCore
import SwiftData

/// 1日分または1計測単位の滑走セッションを永続化する SwiftData モデル
@Model
final class SkiSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date
    var resortID: String?
    var resortNameSnapshot: String
    var totalDistanceMeters: Double
    var pureSkiDistanceMeters: Double
    var maxSpeedKilometersPerHour: Double
    var averageSpeedKilometersPerHour: Double
    var verticalDropMeters: Double
    var runCount: Int
    var elapsedSeconds: TimeInterval
    @Relationship(deleteRule: .cascade) var trackPoints: [TrackPointRecord]

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date,
        resortID: String?,
        resortNameSnapshot: String,
        totalDistanceMeters: Double,
        pureSkiDistanceMeters: Double,
        maxSpeedKilometersPerHour: Double,
        averageSpeedKilometersPerHour: Double,
        verticalDropMeters: Double,
        runCount: Int,
        elapsedSeconds: TimeInterval,
        trackPoints: [TrackPointRecord] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.resortID = resortID
        self.resortNameSnapshot = resortNameSnapshot
        self.totalDistanceMeters = totalDistanceMeters
        self.pureSkiDistanceMeters = pureSkiDistanceMeters
        self.maxSpeedKilometersPerHour = maxSpeedKilometersPerHour
        self.averageSpeedKilometersPerHour = averageSpeedKilometersPerHour
        self.verticalDropMeters = verticalDropMeters
        self.runCount = runCount
        self.elapsedSeconds = elapsedSeconds
        self.trackPoints = trackPoints
    }
}

/// 滑走軌跡の個別GPSポイントを永続化する SwiftData モデル
@Model
final class TrackPointRecord {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var altitudeMeters: Double
    var speedMetersPerSecond: Double
    var horizontalAccuracyMeters: Double

    init(sample: TrackSample) {
        self.timestamp = sample.timestamp
        self.latitude = sample.latitude
        self.longitude = sample.longitude
        self.altitudeMeters = sample.altitudeMeters
        self.speedMetersPerSecond = sample.speedMetersPerSecond
        self.horizontalAccuracyMeters = sample.horizontalAccuracyMeters
    }

    func toTrackSample() -> TrackSample {
        TrackSample(
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            altitudeMeters: altitudeMeters,
            speedMetersPerSecond: speedMetersPerSecond,
            horizontalAccuracyMeters: horizontalAccuracyMeters
        )
    }
}
