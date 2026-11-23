import Foundation

/// ゲレンデ内軌跡上で自動推定されるイベント種別
public enum TrackEventKind: String, Codable, Equatable, Hashable, Sendable {
    /// 転倒したと思われる地点（滑走中からの急停止＋一定時間の静止）
    case possibleFall
    /// 急ブレーキをしたと思われる地点（高速域からの急減速）
    case hardBraking
}

/// 軌跡マップ上にピン表示する推定イベント
public struct TrackEvent: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let kind: TrackEventKind
    public let timestamp: Date
    public let latitude: Double
    public let longitude: Double
    /// 減速前の速度（km/h）
    public let entrySpeedKmh: Double
    /// 推定減速G（m/s² ÷ 9.80665）
    public let decelerationG: Double

    public init(
        id: String,
        kind: TrackEventKind,
        timestamp: Date,
        latitude: Double,
        longitude: Double,
        entrySpeedKmh: Double,
        decelerationG: Double
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.entrySpeedKmh = entrySpeedKmh
        self.decelerationG = decelerationG
    }
}

/// GPS軌跡サンプル列から「転倒推定地点」「急ブレーキ推定地点」を自動検出するディテクタ
public struct TrackEventDetector: Sendable {
    /// 急ブレーキとみなす最小減速度（m/s²）
    public let hardBrakingDecelThreshold: Double
    /// 急ブレーキ判定の対象とする減速前の最低速度（km/h）
    public let hardBrakingMinEntrySpeedKmh: Double
    /// 転倒推定で「急停止後に静止している」とみなす最小継続時間（秒）
    public let fallStillDurationSeconds: TimeInterval
    /// 同一地点での重複イベントを抑止するクールダウン時間（秒）
    public let cooldownSeconds: TimeInterval

    public init(
        hardBrakingDecelThreshold: Double = 2.5,
        hardBrakingMinEntrySpeedKmh: Double = 25.0,
        fallStillDurationSeconds: TimeInterval = 5.0,
        cooldownSeconds: TimeInterval = 15.0
    ) {
        self.hardBrakingDecelThreshold = hardBrakingDecelThreshold
        self.hardBrakingMinEntrySpeedKmh = hardBrakingMinEntrySpeedKmh
        self.fallStillDurationSeconds = fallStillDurationSeconds
        self.cooldownSeconds = cooldownSeconds
    }

    /// 軌跡サンプル列を解析し、転倒推定・急ブレーキ推定イベント一覧を返す
    public func detectEvents(samples: [TrackSample]) -> [TrackEvent] {
        let valid = samples
            .filter { $0.isValid() }
            .sorted { $0.timestamp < $1.timestamp }

        guard valid.count >= 2 else { return [] }

        var events: [TrackEvent] = []
        var lastEventTime: Date?

        for idx in 1..<valid.count {
            let prev = valid[idx - 1]
            let curr = valid[idx]

            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)
            guard dt > 0 && dt <= 10.0 else { continue }

            let prevSpeedKmh = prev.speedKilometersPerHour
            let currSpeedKmh = curr.speedKilometersPerHour
            let speedDropMs = max(0, (prevSpeedKmh - currSpeedKmh) / 3.6)
            let decel = speedDropMs / dt

            // 急停止（転倒候補）：18km/h以上から 3.5km/h以下へ急減速し、その後一定時間静止
            if prevSpeedKmh >= 18.0, currSpeedKmh <= 3.5, decel >= 1.8 {
                let isStillAfterStop = checkStillness(in: valid, fromIndex: idx)
                if isStillAfterStop {
                    if let last = lastEventTime, curr.timestamp.timeIntervalSince(last) < cooldownSeconds {
                        continue
                    }
                    events.append(
                        TrackEvent(
                            id: "fall-\(idx)",
                            kind: .possibleFall,
                            timestamp: curr.timestamp,
                            latitude: curr.latitude,
                            longitude: curr.longitude,
                            entrySpeedKmh: prevSpeedKmh,
                            decelerationG: decel / 9.80665
                        )
                    )
                    lastEventTime = curr.timestamp
                    continue
                }
            }

            // 急ブレーキ候補：25km/h以上から強い減速度（2.5 m/s²以上）かつ15km/h以上減速
            if prevSpeedKmh >= hardBrakingMinEntrySpeedKmh,
               (prevSpeedKmh - currSpeedKmh) >= 15.0,
               decel >= hardBrakingDecelThreshold {
                if let last = lastEventTime, curr.timestamp.timeIntervalSince(last) < cooldownSeconds {
                    continue
                }
                events.append(
                    TrackEvent(
                        id: "brake-\(idx)",
                        kind: .hardBraking,
                        timestamp: curr.timestamp,
                        latitude: curr.latitude,
                        longitude: curr.longitude,
                        entrySpeedKmh: prevSpeedKmh,
                        decelerationG: decel / 9.80665
                    )
                )
                lastEventTime = curr.timestamp
            }
        }

        return events
    }

    /// 指定インデックス以降、fallStillDurationSeconds 以上のあいだ静止状態（速度<=4km/h かつ移動<8m）が続いているか判定
    private func checkStillness(in samples: [TrackSample], fromIndex: Int) -> Bool {
        let stopSample = samples[fromIndex]
        var stillUntil = stopSample.timestamp

        for nextIdx in (fromIndex + 1)..<samples.count {
            let next = samples[nextIdx]
            let dist = ResortMatcher.haversineDistanceMeters(
                lat1: stopSample.latitude,
                lon1: stopSample.longitude,
                lat2: next.latitude,
                lon2: next.longitude
            )
            if next.speedKilometersPerHour <= 4.0 && dist < 8.0 {
                stillUntil = next.timestamp
                if stillUntil.timeIntervalSince(stopSample.timestamp) >= fallStillDurationSeconds {
                    return true
                }
            } else {
                break
            }
        }
        return false
    }
}
