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
    var turnCount: Int = 0
    var turnsPerKilometer: Double = 0
    var turnConsistencyScore: Double = 0
    /// 雪質コンディションタグ（"powder" / "groomed" / "icy" / "slush" / ""）
    var snowConditionRaw: String = ""
    /// ユーザーが自由に記録する滑走メモ
    var sessionMemo: String = ""
    /// 計測中のセッションかどうか（クラッシュ・バッテリー切れ時の自動復旧に使用）
    var isInProgress: Bool = false
    /// Apple ヘルスケアへワークアウトとして保存済みか（重複登録を防止）
    var healthKitExported: Bool = false
    @Relationship(deleteRule: .cascade) var trackPoints: [TrackPointRecord]

    /// 全画面で統一して表示する滑走距離（純粋滑走距離を優先し、未算出時のみ総距離へフォールバック）
    var displaySkiDistanceMeters: Double {
        pureSkiDistanceMeters > 0 ? pureSkiDistanceMeters : totalDistanceMeters
    }

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
        turnCount: Int = 0,
        turnsPerKilometer: Double = 0,
        turnConsistencyScore: Double = 0,
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
        self.turnCount = turnCount
        self.turnsPerKilometer = turnsPerKilometer
        self.turnConsistencyScore = turnConsistencyScore
        self.trackPoints = trackPoints
    }

    func toTurnSnapshot() -> SessionTurnSnapshot {
        SessionTurnSnapshot(
            turnCount: turnCount,
            turnsPerKilometer: turnsPerKilometer,
            consistencyScore: turnConsistencyScore,
            maxSpeedKilometersPerHour: maxSpeedKilometersPerHour
        )
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
