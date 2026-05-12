import SwiftUI
import SwiftData

@main
struct GTimerApp: App {
  @State private var settings = SettingsManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .modelContainer(for: DoseRecord.self)
        .preferredColorScheme(.dark)
    }
  }
}
