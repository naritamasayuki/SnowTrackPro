import Foundation
import os

/// アプリ全体で使用する構造化ロガー
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.snowtrackpro.app"

    static let location = Logger(subsystem: subsystem, category: "Location")
    static let tracking = Logger(subsystem: subsystem, category: "Tracking")
    static let subscription = Logger(subsystem: subsystem, category: "Subscription")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
}
