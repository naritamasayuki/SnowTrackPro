import CoreMotion
import Foundation

/// iPhone 内蔵の気圧高度計（CMAltimeter）を用いて高精度な相対高度変化を取得するサービス
@MainActor
final class BarometerService {
    private let altimeter = CMAltimeter()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.naritamasayuki.SnowTrackPro.barometer"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()

    /// 最新の相対高度（計測開始時からの変化量・メートル）
    private(set) var latestRelativeAltitudeMeters: Double?

    /// 気圧計の計測を開始する（非対応端末・シミュレータでは安全にスキップ）
    func start() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            AppLogger.tracking.info("気圧計非対応環境のため相対高度計測をスキップします。")
            return
        }
        latestRelativeAltitudeMeters = 0
        altimeter.startRelativeAltitudeUpdates(to: queue) { @Sendable [weak self] data, error in
            if let error {
                Task { @MainActor in
                    AppLogger.tracking.error("気圧計取得エラー: \(error.localizedDescription, privacy: .public)")
                }
                return
            }
            guard let data else { return }
            let meters = data.relativeAltitude.doubleValue
            Task { @MainActor [weak self] in
                self?.latestRelativeAltitudeMeters = meters
            }
        }
        AppLogger.tracking.info("気圧高度計（CMAltimeter）の計測を開始しました。")
    }

    /// 気圧計の計測を停止する
    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
        latestRelativeAltitudeMeters = nil
    }
}
