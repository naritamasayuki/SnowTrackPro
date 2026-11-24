import Foundation

/// Slopes / Strava / Google Earth 等と互換性のある標準 GPX 1.1 ファイルを生成するエクスポーター
public struct GPXExporter: Sendable {
    public init() {}

    /// 滑走セッションのトラックポイントから GPX 1.1 XML 文字列を生成する
    public func exportGPX(
        trackName: String,
        startedAt: Date,
        samples: [TrackSample]
    ) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let escapedName = Self.escapeXML(trackName)
        let validSamples = samples
            .filter { $0.isValid() }
            .sorted { $0.timestamp < $1.timestamp }

        var lines: [String] = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="SnowTrack Pro" xmlns="http://www.topografix.com/GPX/1/1">"#,
            "  <metadata>",
            "    <name>\(escapedName)</name>",
            "    <time>\(iso.string(from: startedAt))</time>",
            "  </metadata>",
            "  <trk>",
            "    <name>\(escapedName)</name>",
            "    <type>skiing</type>",
            "    <trkseg>"
        ]

        for sample in validSamples {
            let lat = String(format: "%.6f", sample.latitude)
            let lon = String(format: "%.6f", sample.longitude)
            let ele = String(format: "%.1f", sample.altitudeMeters)
            let time = iso.string(from: sample.timestamp)
            lines.append(#"      <trkpt lat="\#(lat)" lon="\#(lon)">"#)
            lines.append("        <ele>\(ele)</ele>")
            lines.append("        <time>\(time)</time>")
            lines.append("      </trkpt>")
        }

        lines.append("    </trkseg>")
        lines.append("  </trk>")
        lines.append("</gpx>")
        return lines.joined(separator: "\n")
    }

    private static func escapeXML(_ input: String) -> String {
        input
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
