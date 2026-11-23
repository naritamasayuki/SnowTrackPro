import CoreMotion
import Foundation
import SnowTrackCore

/// CoreMotion（ジャイロセンサー）から3軸角速度を省電力で取得するサービス
@MainActor
final class MotionTurnService {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.naritamasayuki.SnowTrackPro.motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    var onGyroSample: ((GyroSample) -> Void)?

    /// 省電力 20Hz でジャイロ計測を開始する（シミュレータ等の非対応端末では安全にスキップ）
    func start() {
        guard motionManager.isGyroAvailable else {
            AppLogger.tracking.info("ジャイロセンサー非対応環境のためモーション計測をスキップします。")
            return
        }
        motionManager.gyroUpdateInterval = 1.0 / 20.0
        motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
            if let error {
                Task { @MainActor in
                    AppLogger.tracking.error("ジャイロ取得エラー: \(error.localizedDescription, privacy: .public)")
                }
                return
            }
            guard let data else { return }
            let sample = GyroSample(
                timestamp: Date(),
                x: data.rotationRate.x,
                y: data.rotationRate.y,
                z: data.rotationRate.z
            )
            Task { @MainActor [weak self] in
                self?.onGyroSample?(sample)
            }
        }
        AppLogger.tracking.info("ジャイロセンサー計測（20Hz）を開始しました。")
    }

    /// ジャイロ計測を停止する
    func stop() {
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
            AppLogger.tracking.info("ジャイロセンサー計測を停止しました。")
        }
    }
}
