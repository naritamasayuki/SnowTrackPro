import Foundation

/// シーズン累計サマリー用の入力セッションデータ
public struct SeasonSessionInput: Equatable, Sendable {
    public let date: Date
    public let resortID: String?
    public let totalDistanceMeters: Double
    public let verticalDropMeters: Double
    public let maxSpeedKilometersPerHour: Double
    public let runCount: Int
    public let turnCount: Int

    public init(
        date: Date,
        resortID: String?,
        totalDistanceMeters: Double,
        verticalDropMeters: Double,
        maxSpeedKilometersPerHour: Double,
        runCount: Int,
        turnCount: Int
    ) {
        self.date = date
        self.resortID = resortID
        self.totalDistanceMeters = totalDistanceMeters
        self.verticalDropMeters = verticalDropMeters
        self.maxSpeedKilometersPerHour = maxSpeedKilometersPerHour
        self.runCount = runCount
        self.turnCount = turnCount
    }
}

/// シーズン累計統計と自己ベスト（PB）サマリー
public struct SeasonStatsSummary: Equatable, Sendable {
    public let sessionCount: Int
    public let totalDistanceMeters: Double
    public let totalVerticalDropMeters: Double
    public let personalBestSpeedKmh: Double
    public let totalRuns: Int
    public let totalTurns: Int
    public let uniqueResortCount: Int

    public init(
        sessionCount: Int = 0,
        totalDistanceMeters: Double = 0,
        totalVerticalDropMeters: Double = 0,
        personalBestSpeedKmh: Double = 0,
        totalRuns: Int = 0,
        totalTurns: Int = 0,
        uniqueResortCount: Int = 0
    ) {
        self.sessionCount = sessionCount
        self.totalDistanceMeters = totalDistanceMeters
        self.totalVerticalDropMeters = totalVerticalDropMeters
        self.personalBestSpeedKmh = personalBestSpeedKmh
        self.totalRuns = totalRuns
        self.totalTurns = totalTurns
        self.uniqueResortCount = uniqueResortCount
    }
}

/// 滑走履歴からシーズン累計および自己ベスト更新有無を算出する計算機
public struct SeasonStatsCalculator: Sendable {
    public init() {}

    /// 全セッションまたは指定期間セッションから累計サマリーを算出する
    public func summarize(sessions: [SeasonSessionInput]) -> SeasonStatsSummary {
        guard !sessions.isEmpty else { return SeasonStatsSummary() }

        let totalDist = sessions.reduce(0) { $0 + max(0, $1.totalDistanceMeters) }
        let totalVert = sessions.reduce(0) { $0 + max(0, $1.verticalDropMeters) }
        let maxSpeed = sessions.map(\.maxSpeedKilometersPerHour).max() ?? 0
        let totalRuns = sessions.reduce(0) { $0 + max(0, $1.runCount) }
        let totalTurns = sessions.reduce(0) { $0 + max(0, $1.turnCount) }
        let resortIDs = Set(sessions.compactMap(\.resortID))

        return SeasonStatsSummary(
            sessionCount: sessions.count,
            totalDistanceMeters: totalDist,
            totalVerticalDropMeters: totalVert,
            personalBestSpeedKmh: max(0, maxSpeed),
            totalRuns: totalRuns,
            totalTurns: totalTurns,
            uniqueResortCount: resortIDs.count
        )
    }

    /// 今回の最高速度が過去セッションの自己ベストを更新したか判定する
    public func isNewPersonalBestSpeed(
        currentMaxSpeedKmh: Double,
        previousMaxSpeedsKmh: [Double]
    ) -> Bool {
        guard currentMaxSpeedKmh > 5.0 else { return false }
        guard let previousBest = previousMaxSpeedsKmh.max() else {
            return true
        }
        return currentMaxSpeedKmh > previousBest + 0.1
    }
}
