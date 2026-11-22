import SwiftUI

struct ContentView: View {
    @State private var trackingViewModel = TrackingViewModel()

    var body: some View {
        TabView {
            TrackingDashboardView(viewModel: trackingViewModel)
                .tabItem {
                    Label("tab.track", systemImage: "figure.skiing.downhill")
                }

            SessionHistoryView()
                .tabItem {
                    Label("tab.history", systemImage: "clock.arrow.circlepath")
                }

            PaywallView()
                .tabItem {
                    Label("tab.pro", systemImage: "crown.fill")
                }
        }
        .tint(Color(red: 0.0, green: 0.88, blue: 0.94))
    }
}
