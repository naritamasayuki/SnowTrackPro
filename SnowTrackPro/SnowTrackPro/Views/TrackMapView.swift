import MapKit
import SnowTrackCore
import SwiftUI

/// 滑走軌跡および速度別カラーヒートマップを描画する MapKit ビュー
struct TrackMapView: View {
    let samples: [TrackSample]
    let speedSegments: [SpeedSegment]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
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
