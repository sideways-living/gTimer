import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(AppNavigation.self) private var nav
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @State private var showAccountSetup = false
  private var tabs: [AppTab] {
    AppTab.allCases.filter { $0 != .map || settings.proBetaAccepted }
  }

  var body: some View {
    Group {
      #if os(macOS)
      macContent
      #else
      iOSContent
      #endif
    }
    .sheet(isPresented: $showAccountSetup) {
      AccountSetupSheet()
        .environment(settings)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .interactiveDismissDisabled(!settings.accountSetupCompleted)
    }
    .onAppear {
      showAccountSetup = !settings.accountSetupCompleted
    }
  }

  private var iOSContent: some View {
    return TabView(selection: Binding(
      get: { nav.selectedTab },
      set: { nav.selectTab($0) }
    )) {
      ForEach(tabs) { tab in
        protectedContent(for: tab)
          .tabItem { Label(tab.title, systemImage: tab.systemImage) }
          .tag(tab.rawValue)
      }
    }
    .tint(AppTheme.accentBlue)
    .onAppear(perform: appOpened)
  }

  #if os(macOS)
  private var macContent: some View {
    ZStack(alignment: .bottom) {
      protectedContent(for: selectedTab)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundPrimary.ignoresSafeArea())

      macBottomBar
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
    .tint(AppTheme.accentBlue)
    .background(AppTheme.backgroundPrimary)
    .onAppear(perform: appOpened)
  }

  private var selectedTab: AppTab {
    let tab = AppTab(rawValue: nav.selectedTab) ?? .timer
    return tab == .map && !settings.proBetaAccepted ? .timer : tab
  }

  private var macBottomBar: some View {
    HStack(spacing: 8) {
      ForEach(tabs) { tab in
        Button {
          nav.selectTab(tab.rawValue)
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

  private func appOpened() {
    NotificationManager.shared.configure()
    LocationManager.shared.refreshAuthorizationStatus()
    if settings.proBetaAccepted && settings.attachLocationToDoses {
      Task { @MainActor in
        let granted = await LocationManager.shared.requestWhenInUsePermissionIfNeeded()
        if granted {
          LocationManager.shared.requestLocationInBackground()
        }
      }
    }
    DoseStore.scheduleReminderForMostRecentDose(context: context, settings: settings)
    guard settings.syncEnabled else { return }
    Task { @MainActor in
      await DoseSyncManager.shared.syncNow(context: context, settings: settings)
    }
  }

  @ViewBuilder
  private func protectedContent(for tab: AppTab) -> some View {
    switch tab {
    case .history:
      HistoryPrivacyGate {
        HistoryView()
      }
    case .map:
      HistoryPrivacyGate {
        #if os(macOS)
        DoseMapView(showsDismissButton: false, bottomBarClearance: 96)
        #else
        DoseMapView(showsDismissButton: false)
        #endif
      }
    default:
      tab.content
    }
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

private struct AccountSetupSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss
  @State private var email = ""
  @State private var password = ""
  @State private var message: String?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Set up gTimer")
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(AppTheme.textPrimary)
          Text("gTimer can run local only. Your email address is your account username. Your email and password are saved on this device to help protect your data and allow PIN recovery if you choose to lock previous-dose views. Device sync is only created later if you start a trial or activate gTimer Pro.")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }

        VStack(alignment: .leading, spacing: 10) {
          TextField("Email address", text: $email)
            .platformKeyboardType(.emailAddress)
            .platformPlainTextEntry()
            .padding(12)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
          SecureField("Password", text: $password)
            .padding(12)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .privacySensitive()
        }

        if let message {
          Text(message)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusAmber)
        }

        Spacer(minLength: 0)

        Button {
          saveAccount()
        } label: {
          Text("Use local account only")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AppTheme.accentBlue)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
      }
      .padding(22)
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    }
    #if os(macOS)
    .frame(width: 520, height: 520)
    #endif
    .onAppear {
      email = settings.accountEmail
    }
  }

  private func saveAccount() {
    let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard cleanEmail.contains("@") else {
      message = "Enter a valid email address."
      return
    }
    guard password.count >= 8 else {
      message = "Password must be at least 8 characters."
      return
    }

    settings.accountEmail = cleanEmail
    settings.syncAccountEmail = cleanEmail
    settings.setAccountPassword(password)
    settings.accountSetupCompleted = true
    dismiss()
  }
}

private struct HistoryPrivacyGate<Content: View>: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(AppNavigation.self) private var nav
  @State private var security = AppSecurityManager.shared
  @State private var pin = ""
  let content: () -> Content

  var body: some View {
    if security.isHistoryLocked(settings: settings) {
      lockedView
    } else {
      content()
    }
  }

  private var lockedView: some View {
    VStack(spacing: 16) {
      Image(systemName: "lock.fill")
        .font(.system(size: 34, weight: .semibold))
        .foregroundStyle(AppTheme.accentBlue)
      Text("Previous doses are locked")
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
      Text("Enter your PIN to view history and maps. You can still record a dose from the gTimer tab without unlocking.")
        .font(.system(size: 14))
        .foregroundStyle(AppTheme.textMuted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)

      PINPad(title: "Enter PIN", pin: $pin) {
        unlockHistory()
      }
      .frame(maxWidth: 280)

      Button("Unlock") {
        unlockHistory()
      }
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 26)
      .padding(.vertical, 11)
      .background(AppTheme.accentBlue)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .buttonStyle(.plain)

      if let message = security.authMessage {
        Text(message)
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.statusAmber)
      }

      Button("Open privacy settings") {
        nav.openSettings(.privacy)
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(AppTheme.accentBlue)
      .buttonStyle(.plain)

      Button("Open gTimer") {
        nav.openTimer()
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(AppTheme.textSecondary)
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(24)
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  private func unlockHistory() {
    _ = security.unlockHistory(pin: pin)
    pin = ""
  }
}

struct PINPad: View {
  let title: String
  @Binding var pin: String
  var onComplete: (() -> Void)? = nil

  private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
  private let digits = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]

  var body: some View {
    VStack(spacing: 10) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppTheme.textSecondary)

      HStack(spacing: 8) {
        ForEach(0..<max(4, pin.count), id: \.self) { index in
          Circle()
            .fill(index < pin.count ? AppTheme.accentBlue : AppTheme.border)
            .frame(width: 10, height: 10)
        }
      }
      .frame(height: 18)
      .accessibilityLabel(pin.isEmpty ? "No digits entered" : "\(pin.count) digits entered")

      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(digits, id: \.self) { digit in
          pinButton(digit) { append(digit) }
        }
        Color.clear.frame(height: 42)
        pinButton("0") { append("0") }
        Button {
          if !pin.isEmpty { pin.removeLast() }
        } label: {
          Image(systemName: "delete.left")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete last digit")
      }
    }
    .privacySensitive()
  }

  private func pinButton(_ digit: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(digit)
        .font(.system(size: 18, weight: .semibold, design: .rounded))
        .foregroundStyle(AppTheme.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(AppTheme.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(digit)
  }

  private func append(_ digit: String) {
    guard pin.count < 8 else { return }
    pin.append(digit)
    if pin.count == 8 { onComplete?() }
  }
}
