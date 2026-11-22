import SwiftData
import SwiftUI

@main
struct SnowTrackProApp: App {
    @State private var subscriptionStore = SubscriptionStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionStore)
                .preferredColorScheme(.dark)
                .task {
                    await subscriptionStore.load()
                }
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }
}
