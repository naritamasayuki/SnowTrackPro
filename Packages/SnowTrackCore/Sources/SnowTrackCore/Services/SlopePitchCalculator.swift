import Foundation

/// 滑走コースの斜度解析結果（角度：度）
public struct SlopePitchSummary: Equatable, Sendable {
    /// 滑走中に記録された最大斜度（度）
    public let maxPitchDegrees: Double
    /// 下降区間の平均斜度（度）
    public let averagePitchDegrees: Double

    public init(maxPitchDegrees: Double = 0, averagePitchDegrees: Double = 0) {
        self.maxPitchDegrees = max(0, maxPitchDegrees)
        self.averagePitchDegrees = max(0, averagePitchDegrees)
    }
}

/// GPS軌跡サンプル列から滑走コースの最大斜度・平均斜度（°）を算出する計算機
public struct SlopePitchCalculator: Sendable {
    /// ノイズを避けるための最小区間水平距離（メートル）
    public let minHorizontalDistanceMeters: Double
    /// 物理的に現実的な最大斜度の上限ガード（度）
    public let maxRealisticPitchDegrees: Double

    public init(
        minHorizontalDistanceMeters: Double = 10.0,
        maxRealisticPitchDegrees: Double = 60.0
    ) {
        self.minHorizontalDistanceMeters = minHorizontalDistanceMeters
        self.maxRealisticPitchDegrees = maxRealisticPitchDegrees
    }

    public func analyze(samples: [TrackSample]) -> SlopePitchSummary {
        let valid = samples
            .filter { $0.isValid() }
            .sorted { $0.timestamp < $1.timestamp }

        guard valid.count >= 2 else { return SlopePitchSummary() }

        var maxPitch = 0.0
        var weightedSum = 0.0
        var totalWeight = 0.0

        for idx in 1..<valid.count {
            let prev = valid[idx - 1]
            let curr = valid[idx]

            let dropMeters = prev.altitudeMeters - curr.altitudeMeters
            guard dropMeters > 0.5 else { continue }

            let horizontalMeters = ResortMatcher.haversineDistanceMeters(
                lat1: prev.latitude,
                lon1: prev.longitude,
                lat2: curr.latitude,
                lon2: curr.longitude
            )
            guard horizontalMeters >= minHorizontalDistanceMeters else { continue }

            let pitchRadians = atan2(dropMeters, horizontalMeters)
            let pitchDegrees = pitchRadians * 180.0 / .pi
            guard pitchDegrees <= maxRealisticPitchDegrees else { continue }

            maxPitch = max(maxPitch, pitchDegrees)
            weightedSum += pitchDegrees * horizontalMeters
            totalWeight += horizontalMeters
        }

        let avgPitch = totalWeight > 0 ? (weightedSum / totalWeight) : 0
        return SlopePitchSummary(maxPitchDegrees: maxPitch, averagePitchDegrees: avgPitch)
    }
}
