import SwiftUI

struct ContentView: View {
  @State private var selectedTab = 0

  var body: some View {
    TabView(selection: $selectedTab) {
      TimerView()
        .tabItem { Label("Timer", systemImage: "timer") }
        .tag(0)

      HistoryView()
        .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        .tag(1)

      HealthView()
        .tabItem { Label("Health", systemImage: "heart.text.square") }
        .tag(2)

      SettingsView()
        .tabItem { Label("Settings", systemImage: "gearshape") }
        .tag(3)

      ProView()
        .tabItem { Label("Pro", systemImage: "star.fill") }
        .tag(4)
    }
    .tint(AppTheme.accentBlue)
    .background(AppTheme.backgroundPrimary)
  }
}
