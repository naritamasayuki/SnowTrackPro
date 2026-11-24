import MapKit
import SnowTrackCore
import SwiftUI

/// 地図の表示スタイル（航空写真＋地名 / 航空写真のみ / 標準地図）
private enum SlopeMapVisualStyle: CaseIterable {
    case hybrid
    case imagery
    case standard

    var mapStyle: MapStyle {
        switch self {
        case .hybrid:
            return .hybrid(elevation: .realistic)
        case .imagery:
            return .imagery(elevation: .realistic)
        case .standard:
            return .standard(elevation: .realistic)
        }
    }

    var iconName: String {
        switch self {
        case .hybrid:
            return "map.fill"
        case .imagery:
            return "globe.asia.australia.fill"
        case .standard:
            return "map"
        }
    }

    func next() -> SlopeMapVisualStyle {
        switch self {
        case .hybrid: return .imagery
        case .imagery: return .standard
        case .standard: return .hybrid
        }
    }
}

/// ゲレンデ内滑走軌跡・速度ヒートマップ・転倒/急ブレーキ推定ピンを描画する MapKit ビュー（全画面拡大・ズーム操作対応）
struct TrackMapView: View {
    let samples: [TrackSample]
    let speedSegments: [SpeedSegment]
    var events: [TrackEvent] = []
    var isFullScreen: Bool = false

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var currentRegion: MKCoordinateRegion?
    @State private var visualStyle: SlopeMapVisualStyle = .hybrid
    @State private var is3DPitchEnabled: Bool = false
    @State private var showFullScreenMap: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Map(position: $cameraPosition, interactionModes: .all) {
                if !speedSegments.isEmpty {
                    ForEach(speedSegments) { segment in
                        MapPolyline(coordinates: [
                            CLLocationCoordinate2D(latitude: segment.startLatitude, longitude: segment.startLongitude),
                            CLLocationCoordinate2D(latitude: segment.endLatitude, longitude: segment.endLongitude)
                        ])
                        .stroke(color(for: segment.band), lineWidth: isFullScreen ? 6 : 5)
                    }
                } else if samples.count >= 2 {
                    MapPolyline(coordinates: samples.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    })
                    .stroke(Color.cyan, lineWidth: isFullScreen ? 5 : 4)
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

                ForEach(events) { event in
                    Annotation(
                        eventLabel(for: event.kind),
                        coordinate: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude)
                    ) {
                        EventPinBadge(kind: event.kind)
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
            .mapStyle(visualStyle.mapStyle)
            .onMapCameraChange(frequency: .onEnd) { context in
                currentRegion = context.region
            }
            .clipShape(RoundedRectangle(cornerRadius: isFullScreen ? 0 : 16, style: .continuous))

            // 左上：速度＆イベント凡例
            legendOverlay

            // 右上＆右下：拡大・ズーム・スタイル切替コントロール
            controlsOverlay
        }
        .fullScreenCover(isPresented: $showFullScreenMap) {
            FullScreenTrackMapSheet(
                samples: samples,
                speedSegments: speedSegments,
                events: events
            )
        }
    }

    @ViewBuilder
    private var legendOverlay: some View {
        if !speedSegments.isEmpty || !events.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !speedSegments.isEmpty {
                    HStack(spacing: 8) {
                        LegendDot(color: .blue, labelKey: "map.speed.low")
                        LegendDot(color: .yellow, labelKey: "map.speed.medium")
                        LegendDot(color: .red, labelKey: "map.speed.high")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }

                if !events.isEmpty {
                    HStack(spacing: 8) {
                        LegendIcon(icon: "figure.fall", color: .pink, labelKey: "map.event.fall")
                        LegendIcon(icon: "exclamationmark.octagon.fill", color: .orange, labelKey: "map.event.hardBrake")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }
            .padding(8)
        }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    if !isFullScreen {
                        MapControlButton(icon: "arrow.up.left.and.arrow.down.right", accessibilityKey: "map.action.expand") {
                            showFullScreenMap = true
                        }
                    }

                    MapControlButton(icon: "plus", accessibilityKey: "map.action.zoomIn") {
                        zoom(factor: 0.5)
                    }

                    MapControlButton(icon: "minus", accessibilityKey: "map.action.zoomOut") {
                        zoom(factor: 2.0)
                    }

                    MapControlButton(icon: "scope", accessibilityKey: "map.action.fitTrack") {
                        fitToTrack()
                    }

                    MapControlButton(
                        icon: is3DPitchEnabled ? "cube.fill" : "cube",
                        accessibilityKey: "map.action.toggle3D"
                    ) {
                        toggle3DView()
                    }

                    MapControlButton(icon: visualStyle.iconName, accessibilityKey: "map.action.switchStyle") {
                        visualStyle = visualStyle.next()
                    }
                }
            }
            Spacer()
        }
        .padding(8)
    }

    /// 現在の表示領域、または軌跡の中心を基準にズームイン／ズームアウトする
    private func zoom(factor: Double) {
        let baseRegion = currentRegion ?? defaultTrackRegion()
        guard let region = baseRegion else { return }

        let minDelta = 0.0005
        let maxDelta = 2.0
        let newSpan = MKCoordinateSpan(
            latitudeDelta: min(maxDelta, max(minDelta, region.span.latitudeDelta * factor)),
            longitudeDelta: min(maxDelta, max(minDelta, region.span.longitudeDelta * factor))
        )
        let updated = MKCoordinateRegion(center: region.center, span: newSpan)
        currentRegion = updated
        withAnimation(.easeInOut(duration: 0.25)) {
            cameraPosition = .region(updated)
        }
    }

    /// 軌跡全体が見やすく収まる位置にカメラをリセットする
    private func fitToTrack() {
        is3DPitchEnabled = false
        if let region = defaultTrackRegion() {
            currentRegion = region
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .region(region)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .automatic
            }
        }
    }

    /// 2D 真上ビュー ⇄ 3D 立体鳥瞰ビュー（ピッチ62°）を切り替える
    private func toggle3DView() {
        is3DPitchEnabled.toggle()
        let region = currentRegion ?? defaultTrackRegion()
        guard let target = region else { return }

        let distance = max(350.0, target.span.latitudeDelta * 111_000.0 * 1.4)
        let camera = MapCamera(
            centerCoordinate: target.center,
            distance: distance,
            heading: 0,
            pitch: is3DPitchEnabled ? 62 : 0
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .camera(camera)
        }
    }

    private func defaultTrackRegion() -> MKCoordinateRegion? {
        guard !samples.isEmpty else { return nil }
        let lats = samples.map(\.latitude)
        let lons = samples.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return nil
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.004),
            longitudeDelta: max((maxLon - minLon) * 1.4, 0.004)
        )
        return MKCoordinateRegion(center: center, span: span)
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

    private func eventLabel(for kind: TrackEventKind) -> String {
        switch kind {
        case .possibleFall:
            return String(localized: "map.event.fall")
        case .hardBraking:
            return String(localized: "map.event.hardBrake")
        }
    }
}

/// ゲレンデ内軌跡を画面いっぱいで拡大・ピンチ操作できるフルスクリーンビュー
private struct FullScreenTrackMapSheet: View {
    @Environment(\.dismiss) private var dismiss

    let samples: [TrackSample]
    let speedSegments: [SpeedSegment]
    let events: [TrackEvent]

    var body: some View {
        NavigationStack {
            TrackMapView(
                samples: samples,
                speedSegments: speedSegments,
                events: events,
                isFullScreen: true
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("map.slopeTrack.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("map.action.close")
                }
            }
        }
    }
}

private struct MapControlButton: View {
    let icon: String
    let accessibilityKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(accessibilityKey)
    }
}

private struct EventPinBadge: View {
    let kind: TrackEventKind

    var body: some View {
        let color: Color = kind == .possibleFall ? .pink : .orange
        let icon: String = kind == .possibleFall ? "figure.fall" : "exclamationmark.octagon.fill"
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
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

private struct LegendIcon: View {
    let icon: String
    let color: Color
    let labelKey: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2.bold())
                .foregroundStyle(color)
            Text(labelKey)
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
    }
}
