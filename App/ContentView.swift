import SwiftUI

struct ContentView: View {
  @Environment(AppNavigation.self) private var nav
  private let tabs = AppTab.allCases

  var body: some View {
    #if os(macOS)
    macContent
    #else
    iOSContent
    #endif
  }

  private var iOSContent: some View {
    @Bindable var nav = nav
    return TabView(selection: $nav.selectedTab) {
      ForEach(tabs) { tab in
        tab.content
          .tabItem { Label(tab.title, systemImage: tab.systemImage) }
          .tag(tab.rawValue)
      }
    }
    .tint(AppTheme.accentBlue)
  }

  #if os(macOS)
  private var macContent: some View {
    NavigationSplitView {
      List(selection: selectedTabBinding) {
        Section("G Timer") {
          ForEach(tabs) { tab in
            Label(tab.title, systemImage: tab.systemImage)
              .tag(tab.rawValue)
          }
        }
      }
      .navigationTitle("G Timer")
      .scrollContentBackground(.hidden)
      .background(AppTheme.backgroundSecondary)
      .listStyle(.sidebar)
    } detail: {
      selectedTab.content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    }
    .tint(AppTheme.accentBlue)
    .background(AppTheme.backgroundPrimary)
  }

  private var selectedTab: AppTab {
    AppTab(rawValue: nav.selectedTab) ?? .timer
  }

  private var selectedTabBinding: Binding<Int> {
    Binding(
      get: { nav.selectedTab },
      set: { nav.selectedTab = $0 }
    )
  }
  #endif
}

private enum AppTab: Int, CaseIterable, Identifiable {
  case timer
  case history
  case health
  case settings
  case pro

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .timer: "Timer"
    case .history: "History"
    case .health: "Health"
    case .settings: "Settings"
    case .pro: "Pro"
    }
  }

  var systemImage: String {
    switch self {
    case .timer: "timer"
    case .history: "clock.arrow.circlepath"
    case .health: "heart.text.square"
    case .settings: "gearshape"
    case .pro: "star.fill"
    }
  }

  @ViewBuilder
  var content: some View {
    switch self {
    case .timer:
      TimerView()
    case .history:
      HistoryView()
    case .health:
      HealthView()
    case .settings:
      SettingsView()
    case .pro:
      ProView()
    }
  }
}
