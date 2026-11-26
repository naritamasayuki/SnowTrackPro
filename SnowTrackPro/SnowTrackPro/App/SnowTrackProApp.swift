import AppTrackingTransparency
import SwiftData
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
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
                        // アプリが完全に前面表示されてからATTダイアログを表示し、その後にAdMobを初期化する
                        try? await Task.sleep(for: .milliseconds(600))
                        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                            _ = await ATTrackingManager.requestTrackingAuthorization()
                        }
                        #if canImport(GoogleMobileAds)
                        await MobileAds.shared.start()
                        #endif
                    }
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }
}
