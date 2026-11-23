import SnowTrackCore
import SwiftData
import SwiftUI

/// SwiftData に保存された滑走セッション履歴一覧および年間保存枠ステータス
struct SessionHistoryView: View {
    @Environment(\.locale) private var locale
    @Environment(ProPurchaseStore.self) private var purchaseStore
    @Query(sort: \SkiSessionRecord.startedAt, order: .reverse) private var sessions: [SkiSessionRecord]

    @State private var showProUpgradeSheet = false

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    private var remainingFreeSaves: Int? {
        purchaseStore.remainingFreeSaves(existingDates: sessions.map(\.startedAt))
    }

    var body: some View {
        NavigationStack {
            List {
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
                            SessionRow(session: session, formatter: formatter)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
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
