import Foundation

/// 滑走中の自動判定状態
public enum MotionActivityState: String, Codable, Equatable, Hashable, Sendable {
    /// 滑走中
    case skiing
    /// リフト乗車中
    case ridingLift
    /// 休憩中・停止中
    case resting
}
