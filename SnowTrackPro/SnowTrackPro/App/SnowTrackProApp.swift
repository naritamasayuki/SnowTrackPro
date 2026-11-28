import SwiftData
import SwiftUI

@main
struct SnowTrackProApp: App {
    @State private var purchaseStore = ProPurchaseStore()
    @State private var adMobController = AdMobController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseStore)
                .environment(adMobController)
                .preferredColorScheme(.dark)
                .task {
                    // 購入状態を確定させてから、広告まわり（UMP → ATT → SDK）を初期化する
                    await purchaseStore.load()
                    await adMobController.initializeIfNeeded(isProUnlocked: purchaseStore.isProUnlocked)
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }
}
