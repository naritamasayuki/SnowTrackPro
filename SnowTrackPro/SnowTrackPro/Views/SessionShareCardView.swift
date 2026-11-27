import SnowTrackCore
import SwiftUI

/// Instagram ストーリーズや X へワンタップ共有できる SNS リザルトカード生成シート
struct SessionShareCardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    let session: SkiSessionRecord
    let samples: [TrackSample]
    let isPersonalBest: Bool

    @State private var renderedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                cardPreview
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .cyan.opacity(0.25), radius: 18, y: 8)
                    .padding(.horizontal)

                if let image = renderedImage {
                    let swiftUIImage = Image(uiImage: image)
                    ShareLink(
                        item: swiftUIImage,
                        subject: Text(session.resortNameSnapshot),
                        message: Text("SnowTrack Pro — https://apps.apple.com/app/id6838124975"),
                        preview: SharePreview(session.resortNameSnapshot, image: swiftUIImage)
                    ) {
                        Label("share.button.shareCard", systemImage: "square.and.arrow.up")
                            .font(.headline.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.cyan, in: Capsule())
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.top)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("share.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                renderCardImage()
            }
        }
    }

    private var cardPreview: some View {
        SessionShareCardCanvas(
            session: session,
            samples: samples,
            isPersonalBest: isPersonalBest,
            locale: locale
        )
    }

    @MainActor
    private func renderCardImage() {
        let renderer = ImageRenderer(
            content: cardPreview
                .frame(width: 360)
                .environment(\.locale, locale)
        )
        renderer.scale = 3.0
        renderedImage = renderer.uiImage
    }
}

/// 実際に画像書き出しされる SNS リザルトカード本体
private struct SessionShareCardCanvas: View {
    let session: SkiSessionRecord
    let samples: [TrackSample]
    let isPersonalBest: Bool
    let locale: Locale

    private var formatter: MeasurementFormatHelper {
        MeasurementFormatHelper(locale: locale)
    }

    var body: some View {
        let maxSpeed = formatter.formattedSpeed(kilometersPerHour: session.maxSpeedKilometersPerHour)
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.resortNameSnapshot)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(session.startedAt, format: .dateTime.year().month().day())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if isPersonalBest {
                    Label("pb.badge.short", systemImage: "trophy.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow, in: Capsule())
                        .foregroundStyle(.black)
                }
            }

            if samples.count >= 2 {
                TrackPathSilhouette(samples: samples)
                    .stroke(
                        LinearGradient(colors: [.blue, .cyan, .yellow, .red], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .frame(height: 110)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(maxSpeed.value)
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(.cyan)
                Text(maxSpeed.unit)
                    .font(.headline.bold())
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("metric.maxSpeed")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                ShareStatPill(titleKey: "metric.distance", value: formatter.formattedDistance(meters: session.displaySkiDistanceMeters))
                ShareStatPill(titleKey: "metric.verticalDrop", value: formatter.formattedElevation(meters: session.verticalDropMeters))
                ShareStatPill(titleKey: "metric.runs", value: "\(session.runCount)")
            }

            HStack {
                Image(systemName: "figure.skiing.downhill")
                    .foregroundStyle(.cyan)
                Text("SnowTrack Pro")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text("share.card.tagline")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.09, blue: 0.18), Color.black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

private struct ShareStatPill: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(titleKey)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// 滑走軌跡のシルエットをオフラインでも美しく描画するカスタム Shape
private struct TrackPathSilhouette: Shape {
    let samples: [TrackSample]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count >= 2 else { return path }

        let lats = samples.map(\.latitude)
        let lons = samples.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return path
        }

        let latSpan = max(maxLat - minLat, 0.0001)
        let lonSpan = max(maxLon - minLon, 0.0001)
        let insetRect = rect.insetBy(dx: 18, dy: 12)

        for (index, sample) in samples.enumerated() {
            let nx = (sample.longitude - minLon) / lonSpan
            let ny = 1.0 - (sample.latitude - minLat) / latSpan
            let point = CGPoint(
                x: insetRect.minX + nx * insetRect.width,
                y: insetRect.minY + ny * insetRect.height
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}
