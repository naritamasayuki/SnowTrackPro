import SnowTrackCore
import StoreKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 雪質コンディションタグの選択肢
enum SnowConditionTag: String, CaseIterable, Identifiable {
    case powder
    case groomed
    case icy
    case slush

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .powder: return "condition.powder"
        case .groomed: return "condition.groomed"
        case .icy: return "condition.icy"
        case .slush: return "condition.slush"
        }
    }

    var iconName: String {
        switch self {
        case .powder: return "snowflake"
        case .groomed: return "lines.measurement.horizontal"
        case .icy: return "sparkles"
        case .slush: return "drop.fill"
        }
    }
}

private extension UTType {
    /// GPX（拡張子ベースの動的型。XML に準拠）
    static let gpxDocument = UTType(filenameExtension: "gpx", conformingTo: .xml) ?? .xml
}

/// ShareLink 押下時にのみ GPX XML を遅延生成する Transferable ドキュメント
private struct GPXTransferDocument: Transferable {
    let trackName: String
    let startedAt: Date
    let samples: [TrackSample]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .gpxDocument) { document in
            let xml = GPXExporter().exportGPX(
                trackName: document.trackName,
                startedAt: document.startedAt,
                samples: document.samples
            )
            return Data(xml.utf8)
        }
        .suggestedFileName("SnowTrack.gpx")
    }
}

/// 滑走セッションの詳細およびプロプラン限定の「グラフ・ターン過去比較コーチング」画面
struct SessionDetailCoachingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(\.requestReview) private var requestReview
    @Environment(ProPurchaseStore.self) private var purchaseStore

    let session: SkiSessionRecord
    let previousSessions: [SkiSessionRecord]

    @State private var showProUpgradeSheet = false
    @State private var showShareCardSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isSavingHealthKit = false
    @State private var healthKitStatusMessage: String?
    @State private var memoDraft: String = ""
    @State private var memoSaveTask: Task<Void, Never>?
    @State private var didDeleteSession = false

    /// 毎描画での全点再計算を防ぐためのキャッシュ
    @State private var cachedSamples: [TrackSample] = []
    @State private var cachedSpeedSegments: [SpeedSegment] = []
    @State private var cachedEvents: [TrackEvent] = []
    @State private var cachedSlopePitch = SlopePitchSummary()
    @State private var hasRequestedReview = false

    private let advisor = TurnCoachingAdvisor()
    private let calculator = TrackMetricsCalculator()
    private let eventDetector = TrackEventDetector()
    private let pitchCalculator = SlopePitchCalculator()
    private let seasonCalculator = SeasonStatsCalculator()
    private let healthKitService = HealthKitWorkoutService()

    private var isPersonalBestSpeed: Bool {
        seasonCalculator.isNewPersonalBestSpeed(
            currentMaxSpeedKmh: session.maxSpeedKilometersPerHour,
            previousMaxSpeedsKmh: previousSessions.map(\.maxSpeedKilometersPerHour)
        )
    }

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    private var coachingReport: TurnCoachingReport {
        advisor.evaluate(
            current: session.toTurnSnapshot(),
            previousSessions: previousSessions.map { $0.toTurnSnapshot() }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isPersonalBestSpeed {
                    Label("pb.banner.title", systemImage: "trophy.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 12))
                }

                summarySection

                slopeTrackSection

                snowConditionMemoSection

                proChartsSection

                turnMetricsSection

                proCoachingSection

                SnowGearShopSectionView()

                exportAndHealthSection

                deleteSessionSection
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(session.resortNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: session.id) {
            memoDraft = session.sessionMemo
            let sorted = session.trackPoints
                .map { $0.toTrackSample() }
                .sorted { $0.timestamp < $1.timestamp }
            cachedSamples = sorted
            cachedSpeedSegments = calculator.buildSpeedSegments(samples: sorted)
            cachedEvents = eventDetector.detectEvents(samples: sorted)
            cachedSlopePitch = pitchCalculator.analyze(samples: sorted)

            if isPersonalBestSpeed && !hasRequestedReview {
                hasRequestedReview = true
                requestReview()
            }
        }
        .onDisappear {
            memoSaveTask?.cancel()
            guard !didDeleteSession else { return }
            if session.sessionMemo != memoDraft {
                session.sessionMemo = memoDraft
                try? modelContext.save()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShareCardSheet = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("share.button.shareCard")
            }
        }
        .sheet(isPresented: $showProUpgradeSheet) {
            ProUpgradeSheet()
        }
        .sheet(isPresented: $showShareCardSheet) {
            SessionShareCardSheet(
                session: session,
                samples: cachedSamples,
                isPersonalBest: isPersonalBestSpeed
            )
        }
        .alert("history.delete.confirmTitle", isPresented: $showDeleteConfirmation) {
            Button("history.delete.confirmAction", role: .destructive) {
                memoSaveTask?.cancel()
                memoSaveTask = nil
                didDeleteSession = true
                modelContext.delete(session)
                try? modelContext.save()
                dismiss()
            }
            Button("action.cancel", role: .cancel) {}
        } message: {
            Text("history.delete.confirmMessage")
        }
    }

    @ViewBuilder
    private var proChartsSection: some View {
        if purchaseStore.isProUnlocked {
            SessionChartsView(samples: cachedSamples, events: cachedEvents)
        } else {
            ZStack {
                SessionChartsView(samples: cachedSamples, events: cachedEvents)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
                    .opacity(0.6)

                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2.bold())
                        .foregroundStyle(.yellow)

                    Text("charts.locked.title")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Button("charts.locked.button") {
                        showProUpgradeSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .foregroundStyle(.black)
                    .font(.caption.bold())
                }
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var snowConditionMemoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("condition.section.title")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(SnowConditionTag.allCases) { tag in
                    let isSelected = session.snowConditionRaw == tag.rawValue
                    Button {
                        session.snowConditionRaw = isSelected ? "" : tag.rawValue
                        try? modelContext.save()
                    } label: {
                        Label(tag.labelKey, systemImage: tag.iconName)
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.cyan : Color.white.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .foregroundStyle(isSelected ? .black : .white)
                    }
                }
            }

            TextField("condition.memo.placeholder", text: $memoDraft, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .padding(10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                .onChange(of: memoDraft) { _, newValue in
                    memoSaveTask?.cancel()
                    memoSaveTask = Task {
                        try? await Task.sleep(for: .milliseconds(450))
                        guard !Task.isCancelled, !didDeleteSession else { return }
                        session.sessionMemo = newValue
                        try? modelContext.save()
                    }
                }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var exportAndHealthSection: some View {
        VStack(spacing: 10) {
            if cachedSamples.count >= 2 {
                let gpxDoc = GPXTransferDocument(
                    trackName: session.resortNameSnapshot,
                    startedAt: session.startedAt,
                    samples: cachedSamples
                )
                ShareLink(
                    item: gpxDoc,
                    preview: SharePreview("SnowTrack-\(session.id.uuidString.prefix(8)).gpx")
                ) {
                    Label("gpx.action.export", systemImage: "doc.badge.arrow.up")
                        .font(.subheadline.bold())
                        .foregroundStyle(.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.cyan.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                        )
                }
            }

            Button {
                Task {
                    isSavingHealthKit = true
                    healthKitStatusMessage = nil
                    defer { isSavingHealthKit = false }
                    do {
                        try await healthKitService.saveSkiWorkout(
                            startedAt: session.startedAt,
                            endedAt: session.endedAt,
                            totalDistanceMeters: session.displaySkiDistanceMeters,
                            resortName: session.resortNameSnapshot
                        )
                        session.healthKitExported = true
                        try? modelContext.save()
                        healthKitStatusMessage = String(localized: "healthkit.saved.success")
                    } catch {
                        healthKitStatusMessage = error.localizedDescription
                    }
                }
            } label: {
                Label(
                    session.healthKitExported ? "healthkit.saved.already" : "healthkit.action.save",
                    systemImage: session.healthKitExported ? "checkmark.heart.fill" : "heart.fill"
                )
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    (session.healthKitExported ? Color.green : Color.pink).opacity(0.28),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke((session.healthKitExported ? Color.green : Color.pink).opacity(0.6), lineWidth: 1)
                )
            }
            .disabled(isSavingHealthKit || session.healthKitExported)

            if let status = healthKitStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deleteSessionSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("history.delete.button", systemImage: "trash")
                .font(.footnote.bold())
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
    }

    private var slopeTrackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("map.slopeTrack.title")
                .font(.headline)
                .foregroundStyle(.white)

            if cachedSamples.count >= 2 {
                TrackMapView(
                    samples: cachedSamples,
                    speedSegments: cachedSpeedSegments,
                    events: cachedEvents
                )
                .frame(height: 240)

                let fallCount = cachedEvents.filter { $0.kind == .possibleFall }.count
                let brakeCount = cachedEvents.filter { $0.kind == .hardBraking }.count
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    DetailStatCard(titleKey: "pitch.max", value: String(format: "%.1f°", cachedSlopePitch.maxPitchDegrees), color: .cyan)
                    DetailStatCard(titleKey: "pitch.average", value: String(format: "%.1f°", cachedSlopePitch.averagePitchDegrees), color: .green)
                    DetailStatCard(titleKey: "map.event.fallCount", value: "\(fallCount)", color: .pink)
                    DetailStatCard(titleKey: "map.event.hardBrakeCount", value: "\(brakeCount)", color: .orange)
                }
            } else {
                Text("map.slopeTrack.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var summarySection: some View {
        let maxSpeed = formatter.formattedSpeed(kilometersPerHour: session.maxSpeedKilometersPerHour)
        return VStack(alignment: .leading, spacing: 10) {
            Text(session.startedAt, format: .dateTime.year().month().day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DetailStatCard(titleKey: "metric.distance", value: formatter.formattedDistance(meters: session.displaySkiDistanceMeters), color: .cyan)
                DetailStatCard(titleKey: "metric.maxSpeed", value: "\(maxSpeed.value) \(maxSpeed.unit)", color: .yellow)
                DetailStatCard(titleKey: "metric.verticalDrop", value: formatter.formattedElevation(meters: session.verticalDropMeters), color: .green)
                DetailStatCard(titleKey: "metric.runs", value: "\(session.runCount)", color: .orange)
            }
        }
    }

    private var turnMetricsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("coaching.turnMetrics.title")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                DetailStatCard(titleKey: "coaching.turnCount", value: "\(session.turnCount)", color: .cyan)
                DetailStatCard(titleKey: "coaching.rhythmScore", value: String(format: "%.0f / 100", session.turnConsistencyScore), color: .green)
            }
        }
    }

    @ViewBuilder
    private var proCoachingSection: some View {
        if purchaseStore.isProUnlocked {
            let report = coachingReport
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("coaching.section.title", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text(arcStyleKey(report.currentArcStyle))
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.cyan.opacity(0.2), in: Capsule())
                        .foregroundStyle(.cyan)
                }

                if report.comparedSessionCount > 0 {
                    HStack(spacing: 12) {
                        if let densityDelta = report.turnDensityDeltaPercent {
                            DeltaPill(
                                labelKey: "coaching.delta.turnDensity",
                                valueText: String(format: "%+.0f%%", densityDelta)
                            )
                        }
                        if let rhythmDelta = report.consistencyDeltaPoints {
                            DeltaPill(
                                labelKey: "coaching.delta.rhythm",
                                valueText: String(format: "%+.0f pt", rhythmDelta)
                            )
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(adviceTitleKey(report.adviceKind))
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Text(adviceBodyKey(report.adviceKind))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                Text("coaching.locked.title")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text("coaching.locked.description")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("coaching.locked.button") {
                    showProUpgradeSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                .font(.subheadline.bold())
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func arcStyleKey(_ style: TurnArcStyle) -> LocalizedStringKey {
        switch style {
        case .short:
            return "coaching.arc.short"
        case .medium:
            return "coaching.arc.medium"
        case .long:
            return "coaching.arc.long"
        }
    }

    private func adviceTitleKey(_ kind: TurnAdviceKind) -> LocalizedStringKey {
        switch kind {
        case .initialBaseline: return "coaching.advice.initial.title"
        case .sharperShortTurns: return "coaching.advice.short.title"
        case .fasterLongTurns: return "coaching.advice.long.title"
        case .improvedRhythm: return "coaching.advice.improved.title"
        case .unstableRhythm: return "coaching.advice.unstable.title"
        case .steadyForm: return "coaching.advice.steady.title"
        }
    }

    private func adviceBodyKey(_ kind: TurnAdviceKind) -> LocalizedStringKey {
        switch kind {
        case .initialBaseline: return "coaching.advice.initial.body"
        case .sharperShortTurns: return "coaching.advice.short.body"
        case .fasterLongTurns: return "coaching.advice.long.body"
        case .improvedRhythm: return "coaching.advice.improved.body"
        case .unstableRhythm: return "coaching.advice.unstable.body"
        case .steadyForm: return "coaching.advice.steady.body"
        }
    }
}

private struct DetailStatCard: View {
    let titleKey: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DeltaPill: View {
    let labelKey: LocalizedStringKey
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(labelKey)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}
