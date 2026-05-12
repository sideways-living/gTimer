import SwiftUI
import SwiftData

@main
struct GTimerApp: App {
  @State private var settings = SettingsManager.shared
  @State private var nav = AppNavigation.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(nav)
        .modelContainer(for: DoseRecord.self)
        .preferredColorScheme(.dark)
        .onOpenURL { url in
          if url.scheme == "gtimer" && url.host == "timer" {
            nav.selectedTab = 0
          }
        }
    }
  }
}
