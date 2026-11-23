import Charts
import SnowTrackCore
import SwiftUI

/// Swift Charts を用いた速度推移・標高推移グラフ（転倒・急ブレーキ地点マーカー付き）
struct SessionChartsView: View {
    @Environment(\.locale) private var locale

    let samples: [TrackSample]
    let events: [TrackEvent]

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    private var chartPoints: [ChartSamplePoint] {
        guard let start = samples.first?.timestamp else { return [] }
        let usesImperial = formatter.usesImperialUnits
        return samples.enumerated().map { idx, sample in
            let elapsedMinutes = sample.timestamp.timeIntervalSince(start) / 60.0
            let speed = usesImperial ? sample.speedKilometersPerHour * 0.621371 : sample.speedKilometersPerHour
            let altitude = usesImperial ? sample.altitudeMeters * 3.28084 : sample.altitudeMeters
            return ChartSamplePoint(
                id: idx,
                elapsedMinutes: elapsedMinutes,
                speed: max(0, speed),
                altitude: altitude
            )
        }
    }

    private var eventMarkers: [ChartEventPoint] {
        guard let start = samples.first?.timestamp else { return [] }
        let usesImperial = formatter.usesImperialUnits
        return events.map { event in
            let elapsedMinutes = event.timestamp.timeIntervalSince(start) / 60.0
            let speed = usesImperial ? event.entrySpeedKmh * 0.621371 : event.entrySpeedKmh
            return ChartEventPoint(
                id: event.id,
                elapsedMinutes: elapsedMinutes,
                speed: speed,
                kind: event.kind
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("charts.section.title")
                .font(.headline)
                .foregroundStyle(.white)

            if chartPoints.count >= 2 {
                speedChartCard
                elevationChartCard
            } else {
                Text("charts.empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var speedChartCard: some View {
        let unitLabel = formatter.usesImperialUnits ? "mph" : "km/h"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("charts.speed.title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.cyan)
                Spacer()
                Text(unitLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(chartPoints) { point in
                    AreaMark(
                        x: .value("Time", point.elapsedMinutes),
                        y: .value("Speed", point.speed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.45), .cyan.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Time", point.elapsedMinutes),
                        y: .value("Speed", point.speed)
                    )
                    .foregroundStyle(.cyan)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(eventMarkers) { marker in
                    PointMark(
                        x: .value("Time", marker.elapsedMinutes),
                        y: .value("Speed", marker.speed)
                    )
                    .foregroundStyle(marker.kind == .possibleFall ? .pink : .orange)
                    .symbolSize(60)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var elevationChartCard: some View {
        let unitLabel = formatter.usesImperialUnits ? "ft" : "m"
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("charts.elevation.title")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text(unitLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart(chartPoints) { point in
                AreaMark(
                    x: .value("Time", point.elapsedMinutes),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green.opacity(0.4), .green.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Time", point.elapsedMinutes),
                    y: .value("Altitude", point.altitude)
                )
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 140)
        }
        .padding()
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ChartSamplePoint: Identifiable {
    let id: Int
    let elapsedMinutes: Double
    let speed: Double
    let altitude: Double
}

private struct ChartEventPoint: Identifiable {
    let id: String
    let elapsedMinutes: Double
    let speed: Double
    let kind: TrackEventKind
}
