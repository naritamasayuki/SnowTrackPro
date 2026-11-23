import SnowTrackCore
import SwiftUI

/// 滑走セッションの詳細およびプロプラン限定の「ターン過去比較＆ワンポイントアドバイス」画面
struct SessionDetailCoachingView: View {
    @Environment(\.locale) private var locale
    @Environment(ProPurchaseStore.self) private var purchaseStore

    let session: SkiSessionRecord
    let previousSessions: [SkiSessionRecord]

    @State private var showProUpgradeSheet = false

    private let advisor = TurnCoachingAdvisor()
    private let calculator = TrackMetricsCalculator()

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    private var trackSamples: [TrackSample] {
        session.trackPoints
            .map { $0.toTrackSample() }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var speedSegments: [SpeedSegment] {
        calculator.buildSpeedSegments(samples: trackSamples)
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
                summarySection

                slopeTrackSection

                turnMetricsSection

                proCoachingSection
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(session.resortNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showProUpgradeSheet) {
            ProUpgradeSheet()
        }
    }

    private var slopeTrackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("map.slopeTrack.title")
                .font(.headline)
                .foregroundStyle(.white)

            if trackSamples.count >= 2 {
                TrackMapView(samples: trackSamples, speedSegments: speedSegments)
                    .frame(height: 240)
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
                DetailStatCard(titleKey: "metric.distance", value: formatter.formattedDistance(meters: session.totalDistanceMeters), color: .cyan)
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
