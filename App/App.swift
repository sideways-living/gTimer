import SwiftUI
import SwiftData

@main
struct GTimerApp: App {
  @State private var settings = SettingsManager.shared
  @State private var nav = AppNavigation.shared
  @State private var updates = AppUpdateManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(nav)
        .environment(updates)
        .modelContainer(for: DoseRecord.self)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .platformMainWindowFrame()
        .sheet(isPresented: $updates.shouldShowUpdateNotes) {
          UpdateNotesSheet()
            .environment(updates)
            .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .onAppear {
          updates.recordAppOpened()
        }
        .onOpenURL { url in
          if url.scheme == "gtimer" && url.host == "timer" {
            nav.selectedTab = 0
          }
        }
    }
  }
}

enum AppUpdateCategory: String, CaseIterable, Identifiable {
  case newFeatures = "New features"
  case minorImprovements = "Minor improvements"
  case bugFixes = "Bug fixes"

  var id: String { rawValue }
}

struct AppUpdateEntry: Identifiable {
  let id = UUID()
  let version: String
  let build: Int
  let category: AppUpdateCategory
  let message: String
}

@Observable
final class AppUpdateManager {
  static let shared = AppUpdateManager()

  private let defaults = UserDefaults.standard
  private let lastOpenedVersionKey = "lastOpenedVersion"
  private let lastOpenedAtKey = "lastOpenedAt"
  private let lastSeenUpdateVersionKey = "lastSeenUpdateVersion"

  var shouldShowUpdateNotes = false

  let entries: [AppUpdateEntry] = [
    AppUpdateEntry(
      version: "0.9.1",
      build: 91,
      category: .bugFixes,
      message: "Updated location lookups to use MapKit geocoding APIs required by iOS 26 and macOS 26."
    ),
    AppUpdateEntry(
      version: "0.9.0",
      build: 90,
      category: .newFeatures,
      message: "Pro colour customisation for accent, main dose button, quick dose buttons, and app background."
    ),
    AppUpdateEntry(
      version: "0.9.0",
      build: 90,
      category: .newFeatures,
      message: "Day, night, and automatic colour schemes. Auto follows the operating system appearance."
    ),
    AppUpdateEntry(
      version: "0.9.0",
      build: 90,
      category: .minorImprovements,
      message: "Version tracking now records when this device last opened the app and when update notes were last seen."
    ),
    AppUpdateEntry(
      version: "0.9.0",
      build: 90,
      category: .minorImprovements,
      message: "The Health page includes a recovery-position illustration with source attribution."
    ),
    AppUpdateEntry(
      version: "0.9.0",
      build: 90,
      category: .bugFixes,
      message: "Desktop location fallback can use the saved home address when live location is unavailable."
    )
  ]

  var currentVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.1"
  }

  var currentBuild: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "91"
  }

  var displayVersion: String {
    "Version \(currentVersion) (\(currentBuild))"
  }

  var unseenEntries: [AppUpdateEntry] {
    guard let lastSeen = defaults.string(forKey: lastSeenUpdateVersionKey) else {
      return entries
    }
    return entries.filter { compareVersion($0.version, isNewerThan: lastSeen) }
  }

  private init() {}

  func recordAppOpened() {
    defaults.set(Date(), forKey: lastOpenedAtKey)
    defaults.set(currentVersion, forKey: lastOpenedVersionKey)
    shouldShowUpdateNotes = !unseenEntries.isEmpty
  }

  func markCurrentUpdatesSeen() {
    defaults.set(currentVersion, forKey: lastSeenUpdateVersionKey)
    shouldShowUpdateNotes = false
  }

  private func compareVersion(_ lhs: String, isNewerThan rhs: String) -> Bool {
    lhs.compare(rhs, options: .numeric) == .orderedDescending
  }
}

struct UpdateNotesSheet: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(AppUpdateManager.self) private var updates

  private var entries: [AppUpdateEntry] {
    let unseen = updates.unseenEntries
    return unseen.isEmpty ? updates.entries.filter { $0.version == updates.currentVersion } : unseen
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("What's new")
              .font(.system(size: 28, weight: .bold))
              .foregroundStyle(AppTheme.textPrimary)
            Text(updates.displayVersion)
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textMuted)
          }

          ForEach(AppUpdateCategory.allCases) { category in
            let categoryEntries = entries.filter { $0.category == category }
            if !categoryEntries.isEmpty {
              updateCategorySection(category, entries: categoryEntries)
            }
          }
        }
        .padding(20)
      }
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            updates.markCurrentUpdatesSeen()
            dismiss()
          }
          .foregroundStyle(AppTheme.accentBlue)
        }
      }
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
  }

  private func updateCategorySection(_ category: AppUpdateCategory, entries: [AppUpdateEntry]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(category.rawValue.uppercased())
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(AppTheme.textMuted)
      VStack(alignment: .leading, spacing: 9) {
        ForEach(entries) { entry in
          HStack(alignment: .top, spacing: 9) {
            Circle()
              .fill(AppTheme.accentBlue)
              .frame(width: 5, height: 5)
              .padding(.top, 7)
            Text(entry.message)
              .font(.system(size: 14))
              .foregroundStyle(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .padding(14)
      .background(AppTheme.backgroundCard)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
    }
  }
}
