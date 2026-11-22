import Foundation

/// スキー場マスターデータの読み込みに関するエラー
public enum ResortCatalogError: Error, Equatable, Sendable {
    case resourceNotFound
    case decodingFailed(String)
}

/// ジオフェンシング判定結果
public struct ResortMatchResult: Equatable, Sendable {
    public let resort: Resort
    /// 現在地からスキー場中心までの距離（メートル）
    public let distanceMeters: Double

    public init(resort: Resort, distanceMeters: Double) {
        self.resort = resort
        self.distanceMeters = distanceMeters
    }
}

/// 現在地から最寄りのスキー場をオフラインで自動判定するサービス
public struct ResortMatcher: Sendable {
    public let resorts: [Resort]

    public init(resorts: [Resort]) {
        self.resorts = resorts
    }

    /// バンドル同梱の `resorts.json` を読み込んで初期化する
    public static func loadBundled() throws -> ResortMatcher {
        guard let url = Bundle.module.url(forResource: "resorts", withExtension: "json") else {
            throw ResortCatalogError.resourceNotFound
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([Resort].self, from: data)
            return ResortMatcher(resorts: decoded)
        } catch {
            throw ResortCatalogError.decodingFailed(error.localizedDescription)
        }
    }

    /// 緯度・経度から有効半径（ジオフェンス）内にある最も近いスキー場を返す
    public func matchResort(latitude: Double, longitude: Double) -> ResortMatchResult? {
        guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else {
            return nil
        }

        var bestMatch: ResortMatchResult?
        for resort in resorts {
            let distance = Self.haversineDistanceMeters(
                lat1: latitude,
                lon1: longitude,
                lat2: resort.latitude,
                lon2: resort.longitude
            )
            guard distance <= resort.radiusMeters else {
                continue
            }
            if let currentBest = bestMatch {
                if distance < currentBest.distanceMeters {
                    bestMatch = ResortMatchResult(resort: resort, distanceMeters: distance)
                }
            } else {
                bestMatch = ResortMatchResult(resort: resort, distanceMeters: distance)
            }
        }
        return bestMatch
    }

    /// 2点間の測地線距離を Haversine の公式で算出する（単位: メートル）
    public static func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let earthRadiusMeters = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let radLat1 = lat1 * .pi / 180.0
        let radLat2 = lat2 * .pi / 180.0

        let halfChordSquared = sin(dLat / 2) * sin(dLat / 2)
            + cos(radLat1) * cos(radLat2) * sin(dLon / 2) * sin(dLon / 2)
        let clamped = min(1.0, max(0.0, halfChordSquared))
        let angularDistance = 2 * atan2(sqrt(clamped), sqrt(1 - clamped))
        return earthRadiusMeters * angularDistance
    }
}
