import SnowTrackCore
import SwiftData
import SwiftUI

/// SwiftData に保存された滑走セッション履歴一覧
struct SessionHistoryView: View {
    @Environment(\.locale) private var locale
    @Query(sort: \SkiSessionRecord.startedAt, order: .reverse) private var sessions: [SkiSessionRecord]

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "history.empty.title",
                        systemImage: "snowflake",
                        description: Text("history.empty.description")
                    )
                } else {
                    List {
                        ForEach(sessions, id: \.id) { session in
                            SessionRow(session: session, formatter: formatter)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
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
