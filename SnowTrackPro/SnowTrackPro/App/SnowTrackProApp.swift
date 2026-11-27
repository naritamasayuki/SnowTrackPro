import AppTrackingTransparency
import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

@main
struct SnowTrackProApp: App {
    @State private var purchaseStore = ProPurchaseStore()
    @State private var hasInitializedAds = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseStore)
                .preferredColorScheme(.dark)
                .task {
                    // 購入状態を確定させてから、広告まわり（UMP → ATT → SDK）を初期化する
                    await purchaseStore.load()
                    guard !hasInitializedAds else { return }
                    hasInitializedAds = true
                    await initializeConsentAndAds()
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }

    /// UMP（GDPR 同意フォーム）→ ATT → Google Mobile Ads SDK の順で安全に初期化する
    @MainActor
    private func initializeConsentAndAds() async {
        // 画面描画が完了してから同意フローを開始する
        try? await Task.sleep(for: .milliseconds(800))

        // Pro（広告なし）ユーザーには同意フォーム・ATT・広告SDKを一切出さない
        guard !purchaseStore.isProUnlocked else { return }

        #if canImport(UserMessagingPlatform)
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: nil)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            AppLogger.tracking.warning("UMP 同意情報の更新に失敗しました: \(error.localizedDescription, privacy: .public)")
        }
        #endif

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        #if canImport(GoogleMobileAds)
        #if canImport(UserMessagingPlatform)
        if ConsentInformation.shared.canRequestAds {
            await MobileAds.shared.start()
        }
        #else
        await MobileAds.shared.start()
        #endif
        #endif
    }
}
