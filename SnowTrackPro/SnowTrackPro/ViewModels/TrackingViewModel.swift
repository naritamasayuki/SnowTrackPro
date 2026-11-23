import CoreLocation
import Foundation
import Observation
import SnowTrackCore
import SwiftData

/// 滑走計測ダッシュボードの状態管理とコアロジック連携を担う ViewModel
@MainActor
@Observable
final class TrackingViewModel {
    private(set) var isTracking: Bool = false
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
    /// 年間無料保存枠の上限に達し、プロプラン購入後の保存を待機しているセッションがあるか
    private(set) var hasPendingUnsavedSession: Bool = false

    private let locationService: LocationTrackingService
    private let motionTurnService = MotionTurnService()
    private let barometerService = BarometerService()
    private let liveActivityManager = TrackingActivityManager()
    private let resortMatcher: ResortMatcher
    private let calculator = TrackMetricsCalculator()
    private let turnAnalyzer = TurnAnalyzer()
    private let eventDetector = TrackEventDetector()
    private var stateMachine = RunStateMachine()
    private var gyroSamples: [GyroSample] = []
    private var sessionStartedAt: Date?
    private var sessionEndedAt: Date?
    private var simulationTask: Task<Void, Never>?

    init(locationService: LocationTrackingService? = nil) {
        self.locationService = locationService ?? LocationTrackingService()
        do {
            self.resortMatcher = try ResortMatcher.loadBundled()
        } catch {
            AppLogger.tracking.error("スキー場マスターの読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
            self.resortMatcher = ResortMatcher(resorts: [])
        }
        bindLocationService()
        motionTurnService.onGyroSample = { [weak self] sample in
            guard let self, self.isTracking else { return }
            self.gyroSamples.append(sample)
        }
    }

    private func bindLocationService() {
        locationService.onSample = { [weak self] sample in
            self?.handleSample(sample)
        }
        locationService.onAuthorizationChange = { [weak self] status in
            guard let self else { return }
            if status == .denied || status == .restricted {
                self.errorMessage = String(localized: "error.locationDenied")
            } else {
                self.errorMessage = nil
            }
        }
        locationService.onError = { [weak self] error in
            self?.errorMessage = error.localizedDescription
        }
    }

    /// 計測を開始する
    func startSession() {
        guard !isTracking else { return }
        resetMetrics()
        sessionStartedAt = Date()
        isTracking = true
        locationService.startTracking()
        motionTurnService.start()
        barometerService.start()
        liveActivityManager.start(resortName: String(localized: "resort.detecting"))
    }

    /// 計測を終了し、保存枠に空きがあれば SwiftData へ保存する。
    /// 無料プランの年間上限（5回）を超過している場合は false を返し、購入後に保存できるようデータを保持する。
    @discardableResult
    func finishSession(modelContext: ModelContext, isPro: Bool) -> Bool {
        guard isTracking else { return true }
        simulationTask?.cancel()
        simulationTask = nil
        locationService.stopTracking()
        motionTurnService.stop()
        barometerService.stop()
        liveActivityManager.end()
        isTracking = false

        let endedAt = Date()
        sessionEndedAt = endedAt
        guard !samples.isEmpty else { return true }

        let existingDates = fetchExistingSessionDates(modelContext: modelContext)
        let quotaPolicy = SaveQuotaPolicy()
        guard quotaPolicy.canSaveSession(existingSessionDates: existingDates, isPro: isPro) else {
            hasPendingUnsavedSession = true
            AppLogger.persistence.info("無料プランの年間保存上限（5回）に達したため保存を保留しました。")
            return false
        }

        persistCurrentSession(modelContext: modelContext)
        return true
    }

    /// プロプラン購入後に保留していたセッションを保存する
    func savePendingSession(modelContext: ModelContext) {
        guard hasPendingUnsavedSession, !samples.isEmpty else { return }
        persistCurrentSession(modelContext: modelContext)
    }

    private func fetchExistingSessionDates(modelContext: ModelContext) -> [Date] {
        let descriptor = FetchDescriptor<SkiSessionRecord>()
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(\.startedAt)
    }

    private func persistCurrentSession(modelContext: ModelContext) {
        let endedAt = sessionEndedAt ?? Date()
        let startedAt = sessionStartedAt ?? endedAt
        let resortName = detectedResort?.localizedName() ?? String(localized: "resort.unknown")
        let pointRecords = samples.map { TrackPointRecord(sample: $0) }
        let effectiveSkiDistance = pureSkiDistanceMeters > 0 ? pureSkiDistanceMeters : summary.totalDistanceMeters
        let turnMetrics = turnAnalyzer.analyze(gyroSamples: gyroSamples, skiDistanceMeters: effectiveSkiDistance)
        let record = SkiSessionRecord(
            startedAt: startedAt,
            endedAt: endedAt,
            resortID: detectedResort?.id,
            resortNameSnapshot: resortName,
            totalDistanceMeters: summary.totalDistanceMeters,
            pureSkiDistanceMeters: pureSkiDistanceMeters,
            maxSpeedKilometersPerHour: summary.maxSpeedKilometersPerHour,
            averageSpeedKilometersPerHour: summary.averageSpeedKilometersPerHour,
            verticalDropMeters: summary.verticalDropMeters,
            runCount: max(runCount, 1),
            elapsedSeconds: max(summary.elapsedSeconds, endedAt.timeIntervalSince(startedAt)),
            turnCount: turnMetrics.turnCount,
            turnsPerKilometer: turnMetrics.turnsPerKilometer,
            turnConsistencyScore: turnMetrics.consistencyScore,
            trackPoints: pointRecords
        )

        modelContext.insert(record)
        do {
            try modelContext.save()
            hasPendingUnsavedSession = false
            AppLogger.persistence.info("滑走セッションを保存しました（ポイント数: \(pointRecords.count)）")
        } catch {
            errorMessage = error.localizedDescription
            AppLogger.persistence.error("滑走セッションの保存に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// シミュレータや室内テスト用にサッポロテイネでのデモ滑走を実行する
    func startDemoSimulation() {
        simulationTask?.cancel()
        resetMetrics()
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

    #if DEBUG
    /// スクリーンショット撮影用にサッポロテイネ滑走途中の状態を即座に再現する
    func loadScreenshotLiveState() {
        simulationTask?.cancel()
        resetMetrics()
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
        summary = calculator.summarize(samples: samples)
        speedSegments = calculator.buildSpeedSegments(samples: samples)
        detectedEvents = eventDetector.detectEvents(samples: samples)

        let resortLabel = detectedResort?.localizedName() ?? String(localized: "resort.detecting")
        let stateLabel: String
        switch activityState {
        case .skiing: stateLabel = String(localized: "state.skiing")
        case .ridingLift: stateLabel = String(localized: "state.lift")
        case .resting: stateLabel = String(localized: "state.resting")
        }
        liveActivityManager.update(
            resortName: resortLabel,
            currentSpeedKmh: currentSpeedKmh,
            maxSpeedKmh: summary.maxSpeedKilometersPerHour,
            distanceMeters: pureSkiDistanceMeters > 0 ? pureSkiDistanceMeters : summary.totalDistanceMeters,
            runCount: runCount,
            activityLabel: stateLabel
        )
    }

    private func resetMetrics() {
        samples.removeAll()
        speedSegments.removeAll()
        detectedEvents.removeAll()
        gyroSamples.removeAll()
        stateMachine.reset()
        hasPendingUnsavedSession = false
        detectedResort = nil
        activityState = .resting
        currentSpeedKmh = 0
        summary = TrackMetricsSummary()
        pureSkiDistanceMeters = 0
        runCount = 0
        errorMessage = nil
    }

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
}
