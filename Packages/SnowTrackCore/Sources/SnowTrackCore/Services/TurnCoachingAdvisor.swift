import Foundation

/// 過去セッション比較の入力となる軽量スナップショット
public struct SessionTurnSnapshot: Equatable, Sendable {
    public let turnCount: Int
    public let turnsPerKilometer: Double
    public let consistencyScore: Double
    public let maxSpeedKilometersPerHour: Double

    public init(
        turnCount: Int,
        turnsPerKilometer: Double,
        consistencyScore: Double,
        maxSpeedKilometersPerHour: Double
    ) {
        self.turnCount = turnCount
        self.turnsPerKilometer = turnsPerKilometer
        self.consistencyScore = consistencyScore
        self.maxSpeedKilometersPerHour = maxSpeedKilometersPerHour
    }
}

/// 過去との比較から導かれるアドバイス種別（UI側で多言語ローカライズ文言へ変換）
public enum TurnAdviceKind: String, Equatable, Sendable {
    /// 比較対象となる過去セッションがまだない初回ベースライン
    case initialBaseline
    /// 以前よりターン密度が増え、細かい切り返し（ショートターン）に変化
    case sharperShortTurns
    /// 以前より大きな弧でスピードに乗ったロングターンに変化
    case fasterLongTurns
    /// 以前よりターンリズムの安定度が大幅に向上
    case improvedRhythm
    /// 以前よりターンリズムにばらつきが出ている（疲労・バーン変化のサイン）
    case unstableRhythm
    /// これまでの傾向と非常に安定したフォームを維持
    case steadyForm
}

/// 過去セッションとの比較結果およびワンポイントアドバイス
public struct TurnCoachingReport: Equatable, Sendable {
    public let adviceKind: TurnAdviceKind
    public let currentArcStyle: TurnArcStyle
    /// 過去平均と比較したターン密度の変化率（%）。過去データなしの場合は nil
    public let turnDensityDeltaPercent: Double?
    /// 過去平均と比較したリズム安定度の差分（pt）。過去データなしの場合は nil
    public let consistencyDeltaPoints: Double?
    /// 過去平均と比較した最高速度の差分（km/h）。過去データなしの場合は nil
    public let maxSpeedDeltaKmh: Double?
    /// 比較対象とした過去セッション数
    public let comparedSessionCount: Int

    public init(
        adviceKind: TurnAdviceKind,
        currentArcStyle: TurnArcStyle,
        turnDensityDeltaPercent: Double?,
        consistencyDeltaPoints: Double?,
        maxSpeedDeltaKmh: Double?,
        comparedSessionCount: Int
    ) {
        self.adviceKind = adviceKind
        self.currentArcStyle = currentArcStyle
        self.turnDensityDeltaPercent = turnDensityDeltaPercent
        self.consistencyDeltaPoints = consistencyDeltaPoints
        self.maxSpeedDeltaKmh = maxSpeedDeltaKmh
        self.comparedSessionCount = comparedSessionCount
    }
}

/// 現在のターン状況と過去の滑走履歴を比較し、変化点とワンポイントアドバイスを生成するサービス
public struct TurnCoachingAdvisor: Sendable {
    public init() {}

    public func evaluate(
        current: SessionTurnSnapshot,
        previousSessions: [SessionTurnSnapshot]
    ) -> TurnCoachingReport {
        let validHistory = previousSessions.filter { $0.turnCount > 0 && $0.turnsPerKilometer > 0 }
        let currentStyle = TurnMetrics.classifyArcStyle(turnsPerKilometer: current.turnsPerKilometer)

        guard !validHistory.isEmpty else {
            return TurnCoachingReport(
                adviceKind: .initialBaseline,
                currentArcStyle: currentStyle,
                turnDensityDeltaPercent: nil,
                consistencyDeltaPoints: nil,
                maxSpeedDeltaKmh: nil,
                comparedSessionCount: 0
            )
        }

        let count = Double(validHistory.count)
        let avgDensity = validHistory.reduce(0) { $0 + $1.turnsPerKilometer } / count
        let avgConsistency = validHistory.reduce(0) { $0 + $1.consistencyScore } / count
        let avgMaxSpeed = validHistory.reduce(0) { $0 + $1.maxSpeedKilometersPerHour } / count

        let densityDeltaPercent = avgDensity > 0
            ? ((current.turnsPerKilometer - avgDensity) / avgDensity) * 100.0
            : 0
        let consistencyDelta = current.consistencyScore - avgConsistency
        let speedDelta = current.maxSpeedKilometersPerHour - avgMaxSpeed

        let advice: TurnAdviceKind
        if consistencyDelta >= 8.0 {
            advice = .improvedRhythm
        } else if consistencyDelta <= -8.0 {
            advice = .unstableRhythm
        } else if densityDeltaPercent >= 15.0 {
            advice = .sharperShortTurns
        } else if densityDeltaPercent <= -15.0 && speedDelta >= 2.0 {
            advice = .fasterLongTurns
        } else {
            advice = .steadyForm
        }

        return TurnCoachingReport(
            adviceKind: advice,
            currentArcStyle: currentStyle,
            turnDensityDeltaPercent: densityDeltaPercent,
            consistencyDeltaPoints: consistencyDelta,
            maxSpeedDeltaKmh: speedDelta,
            comparedSessionCount: validHistory.count
        )
    }
}
