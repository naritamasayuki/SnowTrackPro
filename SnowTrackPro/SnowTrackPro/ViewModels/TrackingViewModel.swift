import CoreLocation
import Foundation
import Observation
import SnowTrackCore
import SwiftData
import UIKit

/// 滑走計測ダッシュボードの状態管理とコアロジック連携を担う ViewModel
@MainActor
@Observable
final class TrackingViewModel {
    private(set) var isTracking: Bool = false
    private(set) var isDemoSession: Bool = false
    private(set) var detectedResort: Resort?
    private(set) var activityState: MotionActivityState = .resting
    private(set) var currentSpeedKmh: Double = 0
    private(set) var summary = TrackMetricsSummary()
    private(set) var pureSkiDistanceMeters: Double = 0
    private(set) var runCount: Int = 0
    private(set) var samples: [TrackSample] = []
    private(set) var speedSegments: [SpeedSegment] = []
    private(set) var detectedEvents: [TrackEvent] = []
    private(set) var errorMessage: String?
    private(set) var statusBannerMessage: String?
    private(set) var isLocationDenied: Bool = false

    /// 表示・保存に使う最高速度（滑走中の信頼できる値を優先し、未算出時は全体集計へフォールバック）
    var maxSpeedKmh: Double {
        stateMachine.maxSkiSpeedKmh > 0 ? stateMachine.maxSkiSpeedKmh : summary.maxSpeedKilometersPerHour
    }

    private let locationService: LocationTrackingService
    private let motionTurnService = MotionTurnService()
    private let barometerService = BarometerService()
    private let resortMatcher: ResortMatcher
    private let calculator = TrackMetricsCalculator()
    private var metricsAccumulator = TrackMetricsCalculator().makeAccumulator()
    private let turnAnalyzer = TurnAnalyzer()
    private let eventDetector = TrackEventDetector()
    private var stateMachine = RunStateMachine()
    private var gyroSamples: [GyroSample] = []
    private var sessionStartedAt: Date?
    private var sessionEndedAt: Date?
    private var simulationTask: Task<Void, Never>?

    /// 計測中のデータをクラッシュやバッテリー切れから守るための逐次永続化レコード
    private var activeSessionRecord: SkiSessionRecord?
    private var activeModelContext: ModelContext?
    private var lastFlushedSampleCount: Int = 0
    private var lastFlushDate: Date = .distantPast
    private var lastMapRebuildSampleCount: Int = 0
    /// 起動後に一度だけ復旧処理を行うためのフラグ（タブ切替の onAppear で再実行させない）
    private var hasAttemptedRecovery: Bool = false
    /// 権限ダイアログの応答待ちの間、開始要求を保持する
    private var pendingStartModelContext: ModelContext?

    init(locationService: LocationTrackingService? = nil) {
        self.locationService = locationService ?? LocationTrackingService()
        do {
            self.resortMatcher = try ResortMatcher.loadBundled()
        } catch {
            AppLogger.tracking.error("スキー場マスターの読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
            self.resortMatcher = ResortMatcher(resorts: [])
        }
        bindLocationService()
        motionTurnService.onGyroBatch = { [weak self] batch in
            guard let self, self.isTracking else { return }
            self.gyroSamples.append(contentsOf: batch)
        }
    }

    private func bindLocationService() {
        locationService.onSample = { [weak self] sample in
            self?.handleSample(sample)
        }
        locationService.onAuthorizationChange = { [weak self] status in
            guard let self else { return }
            if status == .denied || status == .restricted {
                self.pendingStartModelContext = nil
                self.isLocationDenied = true
                self.errorMessage = String(localized: "error.locationDenied")
            } else {
                self.isLocationDenied = false
                self.errorMessage = nil
                if status == .authorizedWhenInUse || status == .authorizedAlways,
                   let context = self.pendingStartModelContext {
                    self.pendingStartModelContext = nil
                    self.startSession(modelContext: context)
                }
            }
        }
        locationService.onError = { [weak self] error in
            if let clError = error as? CLError {
                switch clError.code {
                case .locationUnknown, .denied:
                    return // 一時的なエラー、または onAuthorizationChange 側で案内済み
                default:
                    break
                }
            }
            self?.errorMessage = error.localizedDescription
        }
    }

    /// 起動時にクラッシュやバッテリー切れで残った「計測中」セッションを自動復旧して履歴へ確定保存する
    func recoverInProgressSessionsIfNeeded(modelContext: ModelContext) {
        guard !isTracking, !hasAttemptedRecovery else { return }
        hasAttemptedRecovery = true

        let descriptor = FetchDescriptor<SkiSessionRecord>(
            predicate: #Predicate { $0.isInProgress == true }
        )
        guard let orphaned = try? modelContext.fetch(descriptor), !orphaned.isEmpty else {
            return
        }

        var recoveredCount = 0
        for record in orphaned {
            // 念のため、現在計測中の下書きは対象外にする
            if let active = activeSessionRecord, active.id == record.id { continue }
            if record.trackPoints.isEmpty {
                modelContext.delete(record)
            } else {
                record.isInProgress = false
                if let lastTimestamp = record.trackPoints.map(\.timestamp).max() {
                    record.endedAt = max(record.startedAt, lastTimestamp)
                    record.elapsedSeconds = max(record.elapsedSeconds, record.endedAt.timeIntervalSince(record.startedAt))
                }
                recoveredCount += 1
            }
        }

        do {
            try modelContext.save()
            if recoveredCount > 0 {
                statusBannerMessage = String(localized: "tracking.recoveredSession")
                AppLogger.persistence.info("未完了セッションを自動復旧しました（件数: \(recoveredCount)）")
            }
        } catch {
            AppLogger.persistence.error("未完了セッションの復旧保存に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 計測を開始する（位置情報未決定なら許可要求後に自動開始、拒否時は設定アプリへの誘導を表示）
    func startSession(modelContext: ModelContext) {
        guard !isTracking else { return }

        let status = locationService.authorizationStatus
        if status == .denied || status == .restricted {
            isLocationDenied = true
            errorMessage = String(localized: "error.locationDenied")
            return
        }
        if status == .notDetermined {
            pendingStartModelContext = modelContext
            locationService.requestAuthorization()
            return
        }

        resetMetrics()
        isDemoSession = false
        let now = Date()
        sessionStartedAt = now
        isTracking = true
        activeModelContext = modelContext

        // クラッシュ・バッテリー切れ耐性のため、開始時点で進行中レコードを作成しておく
        let draftRecord = SkiSessionRecord(
            startedAt: now,
            endedAt: now,
            resortID: nil,
            resortNameSnapshot: String(localized: "resort.unknown"),
            totalDistanceMeters: 0,
            pureSkiDistanceMeters: 0,
            maxSpeedKilometersPerHour: 0,
            averageSpeedKilometersPerHour: 0,
            verticalDropMeters: 0,
            runCount: 1,
            elapsedSeconds: 0,
            trackPoints: []
        )
        draftRecord.isInProgress = true
        modelContext.insert(draftRecord)
        try? modelContext.save()
        activeSessionRecord = draftRecord
        lastFlushedSampleCount = 0
        lastFlushDate = now

        locationService.startTracking()
        motionTurnService.start()
        barometerService.start()
    }

    /// 計測を終了し、実計測セッションは常に SwiftData へ確定保存する（データ消失ゼロ設計）。
    /// デモ滑走時は保存を完全にスキップし、履歴やシーズン累計を汚染しない。
    @discardableResult
    func finishSession(modelContext: ModelContext) -> Bool {
        guard isTracking else { return true }
        simulationTask?.cancel()
        simulationTask = nil
        locationService.stopTracking()
        motionTurnService.stop()
        barometerService.stop()
        isTracking = false

        let endedAt = Date()
        sessionEndedAt = endedAt

        // デモ滑走は実データとして保存しない
        if isDemoSession {
            isDemoSession = false
            cleanupActiveDraftIfNeeded(modelContext: modelContext)
            statusBannerMessage = String(localized: "tracking.demoFinished")
            return true
        }

        guard !samples.isEmpty else {
            cleanupActiveDraftIfNeeded(modelContext: modelContext)
            statusBannerMessage = String(localized: "tracking.noGpsSamples")
            return false
        }

        rebuildMapOverlaysIfNeeded()
        finalizeAndPersistSession(modelContext: modelContext, endedAt: endedAt)
        return true
    }

    /// フォアグラウンド復帰時などに地図セグメントとイベントを最新化する
    func rebuildMapOverlaysIfNeeded() {
        guard samples.count != lastMapRebuildSampleCount else { return }
        speedSegments = calculator.buildSpeedSegments(samples: samples)
        detectedEvents = eventDetector.detectEvents(samples: samples)
        lastMapRebuildSampleCount = samples.count
    }

    private func cleanupActiveDraftIfNeeded(modelContext: ModelContext) {
        if let draft = activeSessionRecord {
            modelContext.delete(draft)
            try? modelContext.save()
        }
        activeSessionRecord = nil
        activeModelContext = nil
    }

    private func finalizeAndPersistSession(modelContext: ModelContext, endedAt: Date) {
        let startedAt = sessionStartedAt ?? endedAt
        let resortName = detectedResort?.localizedName() ?? String(localized: "resort.unknown")
        let effectiveSkiDistance = pureSkiDistanceMeters > 0 ? pureSkiDistanceMeters : summary.totalDistanceMeters
        let turnMetrics = turnAnalyzer.analyze(gyroSamples: gyroSamples, skiDistanceMeters: effectiveSkiDistance)

        let record: SkiSessionRecord
        if let existing = activeSessionRecord {
            record = existing
            if lastFlushedSampleCount < samples.count {
                let remainingPoints = samples[lastFlushedSampleCount...].map { TrackPointRecord(sample: $0) }
                record.trackPoints.append(contentsOf: remainingPoints)
            }
        } else {
            record = SkiSessionRecord(
                startedAt: startedAt,
                endedAt: endedAt,
                resortID: detectedResort?.id,
                resortNameSnapshot: resortName,
                totalDistanceMeters: summary.totalDistanceMeters,
                pureSkiDistanceMeters: pureSkiDistanceMeters,
                maxSpeedKilometersPerHour: maxSpeedKmh,
                averageSpeedKilometersPerHour: summary.averageSpeedKilometersPerHour,
                verticalDropMeters: summary.verticalDropMeters,
                runCount: max(runCount, 1),
                elapsedSeconds: max(summary.elapsedSeconds, endedAt.timeIntervalSince(startedAt)),
                turnCount: turnMetrics.turnCount,
                turnsPerKilometer: turnMetrics.turnsPerKilometer,
                turnConsistencyScore: turnMetrics.consistencyScore,
                trackPoints: samples.map { TrackPointRecord(sample: $0) }
            )
            modelContext.insert(record)
        }

        record.startedAt = startedAt
        record.endedAt = endedAt
        record.resortID = detectedResort?.id
        record.resortNameSnapshot = resortName
        record.totalDistanceMeters = summary.totalDistanceMeters
        record.pureSkiDistanceMeters = pureSkiDistanceMeters
        record.maxSpeedKilometersPerHour = maxSpeedKmh
        record.averageSpeedKilometersPerHour = summary.averageSpeedKilometersPerHour
        record.verticalDropMeters = summary.verticalDropMeters
        record.runCount = max(runCount, 1)
        record.elapsedSeconds = max(summary.elapsedSeconds, endedAt.timeIntervalSince(startedAt))
        record.turnCount = turnMetrics.turnCount
        record.turnsPerKilometer = turnMetrics.turnsPerKilometer
        record.turnConsistencyScore = turnMetrics.consistencyScore
        record.isInProgress = false

        do {
            try modelContext.save()
            activeSessionRecord = nil
            activeModelContext = nil
            lastFlushedSampleCount = 0
            statusBannerMessage = String(localized: "tracking.savedSuccess")
            AppLogger.persistence.info("滑走セッションを確定保存しました（ポイント数: \(record.trackPoints.count)）")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.persistence.error("滑走セッションの保存に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 計測中に一定件数または一定時間ごとに SwiftData へ逐次書き出しを行い、強制終了時のデータ消失を防ぐ
    private func flushIncrementalBackupIfNeeded() {
        guard !isDemoSession,
              let record = activeSessionRecord,
              let modelContext = activeModelContext else { return }

        let unsavedCount = samples.count - lastFlushedSampleCount
        let elapsedSinceFlush = Date().timeIntervalSince(lastFlushDate)
        guard unsavedCount >= 10 || (unsavedCount > 0 && elapsedSinceFlush >= 25) else { return }

        let newPoints = samples[lastFlushedSampleCount...].map { TrackPointRecord(sample: $0) }
        record.trackPoints.append(contentsOf: newPoints)
        record.endedAt = Date()
        record.resortID = detectedResort?.id
        record.resortNameSnapshot = detectedResort?.localizedName() ?? String(localized: "resort.unknown")
        record.totalDistanceMeters = summary.totalDistanceMeters
        record.pureSkiDistanceMeters = pureSkiDistanceMeters
        record.maxSpeedKilometersPerHour = maxSpeedKmh
        record.averageSpeedKilometersPerHour = summary.averageSpeedKilometersPerHour
        record.verticalDropMeters = summary.verticalDropMeters
        record.runCount = max(runCount, 1)
        if let startedAt = sessionStartedAt {
            record.elapsedSeconds = max(summary.elapsedSeconds, Date().timeIntervalSince(startedAt))
        }

        do {
            try modelContext.save()
            lastFlushedSampleCount = samples.count
            lastFlushDate = Date()
        } catch {
            AppLogger.persistence.warning("計測中の自動バックアップ保存に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    #if DEBUG
    /// シミュレータや開発テスト用にサッポロテイネでのデモ滑走を実行する（履歴には保存されない）
    func startDemoSimulation() {
        simulationTask?.cancel()
        resetMetrics()
        isDemoSession = true
        sessionStartedAt = Date()
        isTracking = true

        let demoSamples = Self.buildTeineDemoSamples()
        simulationTask = Task { [weak self] in
            for sample in demoSamples {
                if Task.isCancelled { break }
                self?.handleSample(sample)
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    /// スクリーンショット撮影用にサッポロテイネ滑走途中の状態を即座に再現する
    func loadScreenshotLiveState() {
        simulationTask?.cancel()
        resetMetrics()
        isDemoSession = true
        sessionStartedAt = Date().addingTimeInterval(-120)
        isTracking = true
        let demoSamples = Self.buildTeineDemoSamples().dropLast()
        for sample in demoSamples {
            handleSample(sample)
        }
    }
    #endif

    private func handleSample(_ sample: TrackSample) {
        guard isTracking, sample.isValid() else { return }

        samples.append(sample)
        currentSpeedKmh = sample.speedKilometersPerHour

        if detectedResort == nil {
            if let match = resortMatcher.matchResort(latitude: sample.latitude, longitude: sample.longitude) {
                detectedResort = match.resort
                AppLogger.tracking.info("スキー場を自動特定しました: \(match.resort.id, privacy: .public)")
            }
        }

        let previousState = activityState
        activityState = stateMachine.ingest(
            sample,
            barometerRelativeAltitudeMeters: barometerService.latestRelativeAltitudeMeters
        )
        if activityState != previousState {
            locationService.updatePowerMode(for: activityState)
        }

        pureSkiDistanceMeters = stateMachine.pureSkiDistanceMeters
        runCount = stateMachine.runCount
        metricsAccumulator.add(sample)
        summary = metricsAccumulator.summary

        // 地図・イベントは画面に見えている間だけ再構築する（バックグラウンドでは復帰時にまとめて1回）
        if UIApplication.shared.applicationState == .active,
           samples.count <= 40 || samples.count - lastMapRebuildSampleCount >= 5 {
            rebuildMapOverlaysIfNeeded()
        }

        flushIncrementalBackupIfNeeded()
    }

    private func resetMetrics() {
        samples.removeAll()
        speedSegments.removeAll()
        detectedEvents.removeAll()
        gyroSamples.removeAll()
        stateMachine.reset()
        metricsAccumulator = calculator.makeAccumulator()
        detectedResort = nil
        activityState = .resting
        currentSpeedKmh = 0
        summary = TrackMetricsSummary()
        pureSkiDistanceMeters = 0
        runCount = 0
        errorMessage = nil
        statusBannerMessage = nil
        lastFlushedSampleCount = 0
        lastMapRebuildSampleCount = 0
    }

    #if DEBUG
    /// サッポロテイネのゲレンデを模擬したデモ用GPSデータ列を生成する
    private static func buildTeineDemoSamples() -> [TrackSample] {
        let baseDate = Date()
        let coords: [(lat: Double, lon: Double, alt: Double, speedMs: Double)] = [
            (43.0764, 141.1997, 980, 4.5),
            (43.0769, 141.2002, 965, 8.0),
            (43.0775, 141.2008, 945, 11.5),
            (43.0782, 141.2015, 920, 14.2),
            (43.0790, 141.2020, 892, 16.0),
            (43.0798, 141.2028, 865, 13.5),
            (43.0805, 141.2035, 840, 10.2),
            (43.0811, 141.2040, 825, 6.0),
            (43.0814, 141.2043, 820, 0.5)
        ]

        return coords.enumerated().map { index, point in
            TrackSample(
                timestamp: baseDate.addingTimeInterval(Double(index) * 4.0),
                latitude: point.lat,
                longitude: point.lon,
                altitudeMeters: point.alt,
                speedMetersPerSecond: point.speedMs,
                horizontalAccuracyMeters: 5.0
            )
        }
    }
    #endif
}
