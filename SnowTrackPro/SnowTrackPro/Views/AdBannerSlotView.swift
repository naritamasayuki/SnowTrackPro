import OSLog
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Google AdMob のアプリ ID および広告ユニット ID を管理する設定
enum AdMobConfiguration {
    /// AdMob アプリ ID（Info.plist の GADApplicationIdentifier と一致させる）
    static let appId = "ca-app-pub-4261439423960578~9967695096"

    /// 本番用バナー広告ユニット ID（標準 320x50）
    static let bannerAdUnitId = "ca-app-pub-4261439423960578/1944579891"

    /// 実際に広告リクエストで使用するバナー広告ユニット ID（DEBUG 時は Google 公式テスト ID を自動使用）
    static var effectiveBannerAdUnitId: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2934735716"
        #else
        return bannerAdUnitId
        #endif
    }
}

/// 無料ユーザー向けの下部バナー領域（プロプラン購入で自動的に完全非表示）
struct AdBannerSlotView: View {
    @Environment(ProPurchaseStore.self) private var purchaseStore
    @State private var adDidFailToLoad = false
    var onTapUpgrade: () -> Void

    var body: some View {
        if !purchaseStore.isProUnlocked {
            #if canImport(GoogleMobileAds)
            if adDidFailToLoad {
                fallbackTipBanner
            } else {
                GoogleAdMobBannerRepresentable(
                    adUnitID: AdMobConfiguration.effectiveBannerAdUnitId,
                    onAdFailed: {
                        adDidFailToLoad = true
                    },
                    onAdLoaded: {
                        adDidFailToLoad = false
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("Advertisement")
            }
            #else
            fallbackTipBanner
            #endif
        }
    }

    /// オフライン（ゲレンデ圏外）や広告取得失敗時に表示するフォールバックバナー
    private var fallbackTipBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "snowflake")
                .font(.subheadline)
                .foregroundStyle(.cyan)

            Text("banner.tip.pocket")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)

            Spacer(minLength: 4)

            Button("banner.hideWithPro", action: onTapUpgrade)
                .font(.caption2.bold())
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.yellow, in: Capsule())
                .foregroundStyle(.black)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#if canImport(GoogleMobileAds)
/// Google Mobile Ads SDK (v13+) の BannerView を SwiftUI から利用するためのラッパー
private struct GoogleAdMobBannerRepresentable: UIViewRepresentable {
    let adUnitID: String
    let onAdFailed: () -> Void
    let onAdLoaded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAdFailed: onAdFailed, onAdLoaded: onAdLoaded)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = Self.activeRootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = Self.activeRootViewController()
        }
    }

    private static func activeRootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let logger = Logger(subsystem: "com.naritamasayuki.SnowTrackPro", category: "AdBannerSlotView")
        private let onAdFailed: () -> Void
        private let onAdLoaded: () -> Void

        init(onAdFailed: @escaping () -> Void, onAdLoaded: @escaping () -> Void) {
            self.onAdFailed = onAdFailed
            self.onAdLoaded = onAdLoaded
        }

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            logger.debug("AdMobバナー広告の読み込みに成功しました")
            DispatchQueue.main.async { [onAdLoaded] in
                onAdLoaded()
            }
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            logger.warning("AdMobバナー広告の読み込みに失敗しました: \(error.localizedDescription, privacy: .public)")
            DispatchQueue.main.async { [onAdFailed] in
                onAdFailed()
            }
        }
    }
}
#endif
