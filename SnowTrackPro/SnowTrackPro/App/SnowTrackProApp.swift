import SwiftData
import SwiftUI

@main
struct SnowTrackProApp: App {
    @State private var purchaseStore = ProPurchaseStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(purchaseStore)
                .preferredColorScheme(.dark)
                .task {
                    await purchaseStore.load()
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }
}
