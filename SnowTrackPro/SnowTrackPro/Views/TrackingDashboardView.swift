import SnowTrackCore
import SwiftData
import SwiftUI

/// ゲレンデの眩しい雪面でも見やすいハイコントラスト計測ダッシュボード
struct TrackingDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale

    let viewModel: TrackingViewModel

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerStatusRow

                    speedHeroCard

                    metricsGrid

                    TrackMapView(
                        samples: viewModel.samples,
                        speedSegments: viewModel.speedSegments
                    )
                    .frame(height: 220)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    actionControls
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("SnowTrack Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.isTracking {
                        Button("action.simulateRun") {
                            viewModel.startDemoSimulation()
                        }
                        .font(.caption.bold())
                    }
                }
            }
        }
    }

    private var headerStatusRow: some View {
        HStack {
            Label {
                if let resort = viewModel.detectedResort {
                    Text(resort.localizedName(for: locale))
                } else if viewModel.isTracking {
                    Text("resort.detecting")
                } else {
                    Text("resort.unknown")
                }
            } icon: {
                Image(systemName: "mountain.2.fill")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .lineLimit(1)

            Spacer()

            Text(activityLabelKey)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(activityBadgeColor.opacity(0.25), in: Capsule())
                .foregroundStyle(activityBadgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var speedHeroCard: some View {
        let speed = formatter.formattedSpeed(kilometersPerHour: viewModel.currentSpeedKmh)
        return VStack(spacing: 4) {
            Text("metric.currentSpeed")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(speed.value)
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.0, green: 0.92, blue: 0.98))

                Text(speed.unit)
                    .font(.title3.bold())
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var metricsGrid: some View {
        let maxSpeed = formatter.formattedSpeed(kilometersPerHour: viewModel.summary.maxSpeedKilometersPerHour)
        let skiDistance = viewModel.pureSkiDistanceMeters > 0
            ? viewModel.pureSkiDistanceMeters
            : viewModel.summary.totalDistanceMeters

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(
                titleKey: "metric.maxSpeed",
                value: "\(maxSpeed.value) \(maxSpeed.unit)",
                accent: .yellow
            )
            MetricTile(
                titleKey: "metric.distance",
                value: formatter.formattedDistance(meters: skiDistance),
                accent: .cyan
            )
            MetricTile(
                titleKey: "metric.verticalDrop",
                value: formatter.formattedElevation(meters: viewModel.summary.verticalDropMeters),
                accent: .green
            )
            MetricTile(
                titleKey: "metric.runs",
                value: "\(viewModel.runCount)",
                accent: .orange
            )
        }
    }

    @ViewBuilder
    private var actionControls: some View {
        if viewModel.isTracking {
            SlideToStopView {
                viewModel.finishSession(modelContext: modelContext)
            }
        } else {
            Button {
                viewModel.startSession()
            } label: {
                Text("action.startTracking")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Color(red: 0.0, green: 0.92, blue: 0.98), in: Capsule())
            }
        }
    }

    private var activityLabelKey: LocalizedStringKey {
        switch viewModel.activityState {
        case .skiing:
            return "state.skiing"
        case .ridingLift:
            return "state.lift"
        case .resting:
            return "state.resting"
        }
    }

    private var activityBadgeColor: Color {
        switch viewModel.activityState {
        case .skiing:
            return .green
        case .ridingLift:
            return .yellow
        case .resting:
            return .gray
        }
    }
}

private struct MetricTile: View {
    let titleKey: LocalizedStringKey
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
