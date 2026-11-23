import MapKit
import SnowTrackCore
import SwiftUI

/// ゲレンデ内滑走軌跡および速度別カラーヒートマップを描画する MapKit ビュー（無料プランでも利用可能）
struct TrackMapView: View {
    let samples: [TrackSample]
    let speedSegments: [SpeedSegment]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition) {
                if !speedSegments.isEmpty {
                    ForEach(speedSegments) { segment in
                        MapPolyline(coordinates: [
                            CLLocationCoordinate2D(latitude: segment.startLatitude, longitude: segment.startLongitude),
                            CLLocationCoordinate2D(latitude: segment.endLatitude, longitude: segment.endLongitude)
                        ])
                        .stroke(color(for: segment.band), lineWidth: 5)
                    }
                } else if samples.count >= 2 {
                    MapPolyline(coordinates: samples.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(Color.cyan, lineWidth: 4)
                }

                if let first = samples.first {
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: first.latitude,
                        longitude: first.longitude
                    )) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }
                }

                if let latest = samples.last {
                    Annotation("", coordinate: CLLocationCoordinate2D(
                        latitude: latest.latitude,
                        longitude: latest.longitude
                    )) {
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                }
            }
            .mapStyle(.imagery(elevation: .realistic))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !speedSegments.isEmpty {
                HStack(spacing: 8) {
                    LegendDot(color: .blue, labelKey: "map.speed.low")
                    LegendDot(color: .yellow, labelKey: "map.speed.medium")
                    LegendDot(color: .red, labelKey: "map.speed.high")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(8)
            }
        }
    }

    private func color(for band: SpeedBand) -> Color {
        switch band {
        case .low:
            return .blue
        case .medium:
            return .yellow
        case .high:
            return .red
        }
    }
}

private struct LegendDot: View {
    let color: Color
    let labelKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(labelKey)
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
    }
}
