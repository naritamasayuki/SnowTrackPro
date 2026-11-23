import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var trackingViewModel = TrackingViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TrackingDashboardView(viewModel: trackingViewModel)
                .tabItem {
                    Label("tab.track", systemImage: "figure.skiing.downhill")
                }
                .tag(0)

            SessionHistoryView()
                .tabItem {
                    Label("tab.history", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
        }
        .tint(Color(red: 0.0, green: 0.88, blue: 0.94))
        #if DEBUG
        .onAppear {
            applyScreenshotLaunchArguments()
        }
        #endif
    }

    #if DEBUG
    private func applyScreenshotLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--screenshot-live") {
            selectedTab = 0
            trackingViewModel.loadScreenshotLiveState()
        } else if args.contains("--screenshot-history") {
            seedSampleHistoryIfNeeded()
            selectedTab = 1
        }
    }

    private func seedSampleHistoryIfNeeded() {
        let descriptor = FetchDescriptor<SkiSessionRecord>()
        let existingCount = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        let now = Date()
        let samples: [SkiSessionRecord] = [
            SkiSessionRecord(
                startedAt: now.addingTimeInterval(-3600 * 5),
                endedAt: now.addingTimeInterval(-3600 * 1),
                resortID: "sapporo-teine",
                resortNameSnapshot: "サッポロテイネ",
                totalDistanceMeters: 24_800,
                pureSkiDistanceMeters: 18_400,
                maxSpeedKilometersPerHour: 64.2,
                averageSpeedKilometersPerHour: 34.8,
                verticalDropMeters: 3_420,
                runCount: 9,
                elapsedSeconds: 14_400
            ),
            SkiSessionRecord(
                startedAt: now.addingTimeInterval(-86400 * 2 - 3600 * 4),
                endedAt: now.addingTimeInterval(-86400 * 2),
                resortID: "niseko-grand-hirafu",
                resortNameSnapshot: "ニセコ東急 グラン・ヒラフ",
                totalDistanceMeters: 31_200,
                pureSkiDistanceMeters: 23_600,
                maxSpeedKilometersPerHour: 71.5,
                averageSpeedKilometersPerHour: 38.2,
                verticalDropMeters: 4_850,
                runCount: 12,
                elapsedSeconds: 15_200
            ),
            SkiSessionRecord(
                startedAt: now.addingTimeInterval(-86400 * 6 - 3600 * 3),
                endedAt: now.addingTimeInterval(-86400 * 6),
                resortID: "rusutsu-resort",
                resortNameSnapshot: "ルスツリゾート",
                totalDistanceMeters: 19_500,
                pureSkiDistanceMeters: 14_900,
                maxSpeedKilometersPerHour: 58.9,
                averageSpeedKilometersPerHour: 31.5,
                verticalDropMeters: 2_980,
                runCount: 7,
                elapsedSeconds: 11_400
            )
        ]
        for record in samples {
            modelContext.insert(record)
        }
        try? modelContext.save()
    }
    #endif
}
