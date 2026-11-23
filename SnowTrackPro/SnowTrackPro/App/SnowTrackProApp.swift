import SwiftData
import SwiftUI

@main
struct SnowTrackProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [SkiSessionRecord.self, TrackPointRecord.self])
    }
}
