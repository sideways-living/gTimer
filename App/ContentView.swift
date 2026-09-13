import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(AppNavigation.self) private var nav
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  private var tabs: [AppTab] {
    AppTab.allCases.filter { $0 != .map || settings.proBetaAccepted }
  }

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
    .onAppear(perform: syncOnOpen)
  }

  #if os(macOS)
  private var macContent: some View {
    ZStack(alignment: .bottom) {
      selectedTab.content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundPrimary.ignoresSafeArea())

      macBottomBar
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    .tint(AppTheme.accentBlue)
    .background(AppTheme.backgroundPrimary)
    .onAppear(perform: syncOnOpen)
  }

  private var selectedTab: AppTab {
    let tab = AppTab(rawValue: nav.selectedTab) ?? .timer
    return tab == .map && !settings.proBetaAccepted ? .timer : tab
  }

  private var macBottomBar: some View {
    HStack(spacing: 8) {
      ForEach(tabs) { tab in
        Button {
          nav.selectedTab = tab.rawValue
        } label: {
          HStack(spacing: 7) {
            Image(systemName: tab.systemImage)
              .font(.system(size: 13, weight: .semibold))
            Text(tab.title)
              .font(.system(size: 13, weight: .semibold))
              .lineLimit(1)
          }
          .foregroundStyle(tabForeground(for: tab))
          .frame(minWidth: tabMinimumWidth(tab), minHeight: 40)
          .padding(.horizontal, 4)
          .background(
            Capsule()
              .fill(tabBackground(for: tab))
          )
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
      }
    }
    .padding(7)
    .background(AppTheme.backgroundElevated.opacity(0.98), in: Capsule())
    .overlay(Capsule().stroke(AppTheme.border.opacity(0.95), lineWidth: 1))
    .shadow(color: Color.black.opacity(0.34), radius: 18, x: 0, y: 10)
  }

  private func tabForeground(for tab: AppTab) -> Color {
    if tab == .pro {
      return .white
    }
    return nav.selectedTab == tab.rawValue ? .white : AppTheme.textSecondary
  }

  private func tabBackground(for tab: AppTab) -> Color {
    if tab == .pro {
      return AppTheme.proAmber
    }
    guard nav.selectedTab == tab.rawValue else {
      return AppTheme.backgroundPrimary.opacity(0.58)
    }
    return AppTheme.accentBlue
  }

  private func tabMinimumWidth(_ tab: AppTab) -> CGFloat {
    switch tab {
    case .pro: 104
    case .map: 78
    default: 82
    }
  }
  #endif

  private func syncOnOpen() {
    guard settings.syncEnabled else { return }
    DoseSyncManager.shared.syncAfterLocalChange(context: context, settings: settings)
  }
}

private enum AppTab: Int, CaseIterable, Identifiable {
  case timer
  case history
  case map
  case health
  case settings
  case pro

  var id: Int { rawValue }

  var title: String {
    switch self {
    case .timer: "gTimer"
    case .history: "History"
    case .health: "Health"
    case .settings: "Settings"
    case .pro: "gTimer Pro"
    case .map: "Map"
    }
  }

  var systemImage: String {
    switch self {
    case .timer: "timer"
    case .history: "clock.arrow.circlepath"
    case .health: "heart.text.square"
    case .settings: "gearshape"
    case .pro: "star.fill"
    case .map: "map.fill"
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
    case .map:
      #if os(macOS)
      DoseMapView(showsDismissButton: false, bottomBarClearance: 96)
      #else
      DoseMapView(showsDismissButton: false)
      #endif
    }
  }
}
