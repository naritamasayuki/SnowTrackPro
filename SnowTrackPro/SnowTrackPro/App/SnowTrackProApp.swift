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
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchaseStore = ProPurchaseStore()
    @State private var hasInitializedAds = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseStore)
                .preferredColorScheme(.dark)
                .task {
                    await purchaseStore.load()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active, !hasInitializedAds else { return }
                    hasInitializedAds = true
                    Task {
                        await initializeConsentAndAds()
                    }
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }

    /// UMP（GDPR 同意フォーム）→ ATT → Google Mobile Ads SDK の順で安全に初期化する
    @MainActor
    private func initializeConsentAndAds() async {
        // 画面描画が完了してから同意フローを開始する
        try? await Task.sleep(for: .milliseconds(800))

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
