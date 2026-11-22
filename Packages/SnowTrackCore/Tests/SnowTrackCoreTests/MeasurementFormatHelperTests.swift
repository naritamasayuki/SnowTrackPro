import Foundation
import Testing
@testable import SnowTrackCore

@Suite("ロケール別単位フォーマット（MeasurementFormatHelper）テスト")
struct MeasurementFormatHelperTests {
    @Test("日本ロケールではメートル法（km/h, km, m）で出力される")
    func metricFormatting() {
        let helper = MeasurementFormatHelper(locale: Locale(identifier: "ja_JP"))
        #expect(helper.usesImperialUnits == false)

        let speed = helper.formattedSpeed(kilometersPerHour: 42.5)
        #expect(speed.value == "42.5")
        #expect(speed.unit == "km/h")
        #expect(helper.formattedDistance(meters: 3450) == "3.45 km")
        #expect(helper.formattedElevation(meters: 680) == "680 m")
    }

    @Test("米国ロケールではヤード・ポンド法（mph, mi, ft）で出力される")
    func imperialFormatting() {
        let helper = MeasurementFormatHelper(locale: Locale(identifier: "en_US"))
        #expect(helper.usesImperialUnits == true)

        let speed = helper.formattedSpeed(kilometersPerHour: 100.0)
        #expect(speed.value == "62.1")
        #expect(speed.unit == "mph")
        #expect(helper.formattedDistance(meters: 1609.344) == "1.00 mi")
        #expect(helper.formattedElevation(meters: 100) == "328 ft")
    }

    @Test("経過時間フォーマットと負値ガードが正しく動作する")
    func durationAndNegativeGuard() {
        let helper = MeasurementFormatHelper(locale: Locale(identifier: "ja_JP"))
        #expect(helper.formattedDuration(seconds: 65) == "01:05")
        #expect(helper.formattedDuration(seconds: 3661) == "1:01:01")
        #expect(helper.formattedDuration(seconds: -10) == "00:00")
        #expect(helper.formattedSpeed(kilometersPerHour: -5).value == "0.0")
    }
}
