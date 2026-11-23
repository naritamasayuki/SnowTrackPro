import SnowTrackCore
import SwiftData
import SwiftUI

/// SwiftData に保存された滑走セッション履歴一覧・シーズン累計サマリー・年間保存枠ステータス
struct SessionHistoryView: View {
    @Environment(\.locale) private var locale
    @Environment(ProPurchaseStore.self) private var purchaseStore
    @Query(sort: \SkiSessionRecord.startedAt, order: .reverse) private var sessions: [SkiSessionRecord]

    @State private var showProUpgradeSheet = false

    private let seasonCalculator = SeasonStatsCalculator()

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    private var remainingFreeSaves: Int? {
        purchaseStore.remainingFreeSaves(existingDates: sessions.map(\.startedAt))
    }

    private var seasonSummary: SeasonStatsSummary {
        let inputs = sessions.map {
            SeasonSessionInput(
                date: $0.startedAt,
                resortID: $0.resortID,
                totalDistanceMeters: $0.totalDistanceMeters,
                verticalDropMeters: $0.verticalDropMeters,
                maxSpeedKilometersPerHour: $0.maxSpeedKilometersPerHour,
                runCount: $0.runCount,
                turnCount: $0.turnCount
            )
        }
        return seasonCalculator.summarize(sessions: inputs)
    }

    var body: some View {
        NavigationStack {
            List {
                if !sessions.isEmpty {
                    Section("season.summary.title") {
                        seasonSummaryCard
                    }
                }

                Section {
                    quotaStatusRow
                }

                if sessions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "history.empty.title",
                            systemImage: "snowflake",
                            description: Text("history.empty.description")
                        )
                    }
                } else {
                    Section {
                        ForEach(sessions, id: \.id) { session in
                            let olderSessions = sessions.filter { $0.startedAt < session.startedAt }
                            NavigationLink {
                                SessionDetailCoachingView(session: session, previousSessions: olderSessions)
                            } label: {
                                SessionRow(session: session, formatter: formatter)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .safeAreaInset(edge: .bottom) {
                AdBannerSlotView {
                    showProUpgradeSheet = true
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
            }
            .navigationTitle("history.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let privacyURL = LegalLinks.privacyPolicyURL {
                        Link(destination: privacyURL) {
                            Image(systemName: "hand.raised.fill")
                        }
                        .accessibilityLabel("legal.privacyPolicy")
                    }
                }
            }
            .sheet(isPresented: $showProUpgradeSheet) {
                ProUpgradeSheet()
            }
        }
    }

    private var seasonSummaryCard: some View {
        let pbSpeed = formatter.formattedSpeed(kilometersPerHour: seasonSummary.personalBestSpeedKmh)
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                SeasonMiniStat(
                    titleKey: "season.pbSpeed",
                    value: "\(pbSpeed.value) \(pbSpeed.unit)",
                    color: .yellow
                )
                SeasonMiniStat(
                    titleKey: "season.totalDistance",
                    value: formatter.formattedDistance(meters: seasonSummary.totalDistanceMeters),
                    color: .cyan
                )
            }
            HStack(spacing: 12) {
                SeasonMiniStat(
                    titleKey: "season.totalVertical",
                    value: formatter.formattedElevation(meters: seasonSummary.totalVerticalDropMeters),
                    color: .green
                )
                SeasonMiniStat(
                    titleKey: "season.resortsAndRuns",
                    value: "\(seasonSummary.uniqueResortCount) / \(seasonSummary.totalRuns)",
                    color: .orange
                )
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var quotaStatusRow: some View {
        if let remaining = remainingFreeSaves {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("pro.quota.freeTitle")
                        .font(.subheadline.bold())
                    Text("pro.quota.remaining \(remaining) \(SaveQuotaPolicy.annualFreeSaveLimit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("pro.quota.upgradeButton") {
                    showProUpgradeSheet = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.yellow)
                .foregroundStyle(.black)
                .font(.caption.bold())
            }
            .padding(.vertical, 4)
        } else {
            Label("pro.badge.active", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        }
    }
}

private struct SeasonMiniStat: View {
    let titleKey: LocalizedStringKey
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titleKey)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SessionRow: View {
    let session: SkiSessionRecord
    let formatter: MeasurementFormatHelper

    var body: some View {
        let maxSpeed = formatter.formattedSpeed(kilometersPerHour: session.maxSpeedKilometersPerHour)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.resortNameSnapshot)
                    .font(.headline)
                Spacer()
                Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(
                    formatter.formattedDistance(meters: session.totalDistanceMeters),
                    systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                )
                Label("\(maxSpeed.value) \(maxSpeed.unit)", systemImage: "speedometer")
                Label(formatter.formattedElevation(meters: session.verticalDropMeters), systemImage: "arrow.down.right")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.cyan)
        }
        .padding(.vertical, 4)
    }
}
