import CoreLocation
import Foundation
import SnowTrackCore

/// CoreLocation を用いたバックグラウンド対応GPSトラッキングサービス
@MainActor
final class LocationTrackingService: NSObject {
    private let manager: CLLocationManager

    var onSample: ((TrackSample) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onError: ((Error) -> Void)?

    private(set) var authorizationStatus: CLAuthorizationStatus

    override init() {
        let locationManager = CLLocationManager()
        self.manager = locationManager
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 3.0
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    /// 位置情報の利用権限（常に許可 / 使用中）をリクエストする
    func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    /// バックグラウンド対応でGPS計測を開始する
    func startTracking() {
        requestAuthorization()
        configureBackgroundUpdates(enabled: true)
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.startUpdatingLocation()
        AppLogger.location.info("GPSトラッキングを開始しました。")
    }

    /// GPS計測を停止する
    func stopTracking() {
        manager.stopUpdatingLocation()
        configureBackgroundUpdates(enabled: false)
        AppLogger.location.info("GPSトラッキングを停止しました。")
    }

    /// 滑走状態に応じてGPS精度を動的に切り替え、寒冷地でのバッテリー消費を抑制する
    func updatePowerMode(for state: MotionActivityState) {
        switch state {
        case .skiing:
            manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            manager.distanceFilter = 2.0
        case .ridingLift:
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = 10.0
        case .resting:
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            manager.distanceFilter = 8.0
        }
    }

    private func configureBackgroundUpdates(enabled: Bool) {
        let backgroundModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        guard backgroundModes.contains("location") else {
            AppLogger.location.warning("Info.plist に location バックグラウンドモードが未設定のためスキップします。")
            return
        }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }
}

extension LocationTrackingService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = status
            self.onAuthorizationChange?(status)
            AppLogger.location.info("位置情報権限ステータス変更: \(status.rawValue)")
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let samples = locations.map { location in
            TrackSample(
                timestamp: location.timestamp,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitudeMeters: location.altitude,
                speedMetersPerSecond: location.speed,
                horizontalAccuracyMeters: location.horizontalAccuracy
            )
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for sample in samples {
                self.onSample?(sample)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            AppLogger.location.error("位置情報取得エラー: \(error.localizedDescription, privacy: .public)")
            self.onError?(error)
        }
    }
}
