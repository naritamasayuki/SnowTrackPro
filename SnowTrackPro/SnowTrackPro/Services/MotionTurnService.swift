import CoreMotion
import Foundation
import SnowTrackCore

/// モーションキュー上でのみ触るジャイロのバッファ（キューは maxConcurrentOperationCount = 1 の直列キュー）
private final class GyroBatchBuffer: @unchecked Sendable {
    var samples: [GyroSample] = []
}

/// CoreMotion のジャイロセンサーから 20Hz で回転速度を取得し、バッチ転送でターン解析へ渡すサービス
@MainActor
final class MotionTurnService {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.naritamasayuki.SnowTrackPro.motion"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    /// この件数ごとにまとめてメインスレッドへ渡す（20Hz なら約1秒ごと）
    private let batchSize = 20

    var onGyroBatch: (([GyroSample]) -> Void)?

    func start() {
        guard motionManager.isGyroAvailable else {
            AppLogger.tracking.info("ジャイロセンサー非対応環境のためモーション計測をスキップします。")
            return
        }
        let buffer = GyroBatchBuffer()
        let batchSize = self.batchSize
        motionManager.gyroUpdateInterval = 1.0 / 20.0
        motionManager.startGyroUpdates(to: queue) { [weak self] data, error in
            if let error {
                Task { @MainActor in
                    AppLogger.tracking.error("ジャイロ取得エラー: \(error.localizedDescription, privacy: .public)")
                }
                return
            }
            guard let data else { return }
            buffer.samples.append(GyroSample(
                timestamp: Date(),
                x: data.rotationRate.x,
                y: data.rotationRate.y,
                z: data.rotationRate.z
            ))
            guard buffer.samples.count >= batchSize else { return }
            let batch = buffer.samples
            buffer.samples.removeAll(keepingCapacity: true)
            Task { @MainActor [weak self] in
                self?.onGyroBatch?(batch)
            }
        }
        AppLogger.tracking.info("ジャイロセンサー計測（20Hz・バッチ転送）を開始しました。")
    }

    func stop() {
        if motionManager.isGyroActive {
            motionManager.stopGyroUpdates()
            AppLogger.tracking.info("ジャイロセンサー計測を停止しました。")
        }
    }
}
