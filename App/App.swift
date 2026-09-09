import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@main
struct GTimerApp: App {
  @State private var settings = SettingsManager.shared
  @State private var nav = AppNavigation.shared
  @State private var updates = AppUpdateManager.shared
  @State private var upgrade = GitHubUpgradeManager.shared

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(settings)
        .environment(nav)
        .environment(updates)
        .environment(upgrade)
        .modelContainer(for: DoseRecord.self)
        .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        .platformMainWindowFrame()
        .alert("gTimer update available", isPresented: $upgrade.shouldShowUpgradeAlert) {
          Button("Later", role: .cancel) {
            upgrade.dismissCurrentUpgrade()
          }
          Button("Download") {
            upgrade.openDownload()
          }
          if upgrade.availableRelease?.releaseNotesURL != nil {
            Button("Release notes") {
              upgrade.openReleaseNotes()
            }
          }
        } message: {
          if let release = upgrade.availableRelease {
            Text("\(release.displayVersion) is available.\n\(release.summary)")
          } else {
            Text("A newer version of gTimer is available.")
          }
        }
        .alert("Quit gTimer?", isPresented: $nav.shouldShowQuitWarning) {
          Button("Cancel", role: .cancel) {}
          Button("Quit", role: .destructive) {
            #if os(macOS)
            NSApp.terminate(nil)
            #endif
          }
        } message: {
          Text("Any open sheets or unfinished edits will be closed.")
        }
        .sheet(isPresented: $updates.shouldShowUpdateNotes) {
          UpdateNotesSheet()
            .environment(updates)
            .preferredColorScheme(settings.appearanceMode.preferredColorScheme)
        }
        .onAppear {
          updates.recordAppOpened()
          upgrade.checkForUpdates()
        }
        .onOpenURL { url in
          if url.scheme == "gtimer" && url.host == "timer" {
            nav.selectedTab = 0
          }
        }
    }
    .commands {
      CommandGroup(after: .appInfo) {
        Button("Settings") {
          nav.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }

      CommandMenu("Open Tabs") {
        Button("gTimer") { nav.openTimer() }
          .keyboardShortcut("1", modifiers: .command)
        Button("History") { nav.openHistory() }
          .keyboardShortcut("2", modifiers: .command)
        Button("Health") { nav.openHealth() }
          .keyboardShortcut("3", modifiers: .command)
        Button("Settings") { nav.openSettings() }
          .keyboardShortcut("4", modifiers: .command)
        Button("gTimer Pro") { nav.openPro() }
          .keyboardShortcut("5", modifiers: .command)
        Button("Map") { nav.requestDoseMap() }
          .keyboardShortcut("6", modifiers: .command)
      }

      CommandGroup(replacing: .newItem) {
        Button("New Dose") {
          nav.requestNewDose()
        }
        .keyboardShortcut("n", modifiers: .command)
      }

      CommandGroup(replacing: .saveItem) {
        Button("Export History to PDF") {
          nav.requestHistoryExport(outcome: .export)
        }
        .keyboardShortcut("s", modifiers: .command)
      }

      CommandGroup(replacing: .printItem) {
        Button("Print History") {
          nav.requestHistoryExport(outcome: .print)
        }
        .keyboardShortcut("p", modifiers: .command)
      }

      CommandGroup(replacing: .appTermination) {
        Button("Quit gTimer") {
          nav.requestQuitConfirmation()
        }
        .keyboardShortcut("q", modifiers: .command)
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
      version: "0.9.15",
      build: 105,
      category: .minorImprovements,
      message: "Spread the shared dose amount and date/time controls across the dose details row and added an ml label after the amount field."
    ),
    AppUpdateEntry(
      version: "0.9.14",
      build: 104,
      category: .minorImprovements,
      message: "Moved the shared dose location field below notes, made it full width, and kept location suggestions directly underneath it."
    ),
    AppUpdateEntry(
      version: "0.9.13",
      build: 103,
      category: .minorImprovements,
      message: "Kept the gTimer Pro menu button as a gold button with white star and text in every navigation state."
    ),
    AppUpdateEntry(
      version: "0.9.12",
      build: 102,
      category: .minorImprovements,
      message: "Added Command-6 for the dose map and made history PDF export include a full-page rendered map when map output is selected."
    ),
    AppUpdateEntry(
      version: "0.9.11",
      build: 101,
      category: .minorImprovements,
      message: "Made add dose, missed dose, and edit dose windows use a shared location-aware form with a wider layout, map pin selection, location search suggestions, and current/home location shortcuts."
    ),
    AppUpdateEntry(
      version: "0.9.10",
      build: 100,
      category: .minorImprovements,
      message: "Added macOS menu commands for opening app sections, logging a new dose, exporting or printing history, opening Settings from the app menu, and confirming before quit."
    ),
    AppUpdateEntry(
      version: "0.9.9",
      build: 99,
      category: .newFeatures,
      message: "Added embedded iOS and macOS widgets with small, medium, and large layouts that show timer status, last dose details, interval progress, and open gTimer from the widget."
    ),
    AppUpdateEntry(
      version: "0.9.8",
      build: 98,
      category: .minorImprovements,
      message: "Improved the desktop bottom menu with stronger contrast, full-button click targets, and a gold gTimer Pro item."
    ),
    AppUpdateEntry(
      version: "0.9.7",
      build: 97,
      category: .minorImprovements,
      message: "Expanded missed-dose logging with no location, current location, saved home location, and searched or manually entered location options."
    ),
    AppUpdateEntry(
      version: "0.9.6",
      build: 96,
      category: .minorImprovements,
      message: "Improved the dose map presentation with a full-screen layout and marker info bubbles."
    ),
    AppUpdateEntry(
      version: "0.9.5",
      build: 95,
      category: .newFeatures,
      message: "Added GitHub-based update checks with release metadata for future downloadable versions."
    ),
    AppUpdateEntry(
      version: "0.9.4",
      build: 94,
      category: .minorImprovements,
      message: "Refined timer button styling so the button areas render as solid rounded rectangles."
    ),
    AppUpdateEntry(
      version: "0.9.3",
      build: 93,
      category: .minorImprovements,
      message: "Refined the macOS timer panel spacing and matched the centre drop colour to the main dose button."
    ),
    AppUpdateEntry(
      version: "0.9.2",
      build: 92,
      category: .minorImprovements,
      message: "Adjusted the timer face by enlarging the centre drop icon and removing the extra arc-tip marker."
    ),
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
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.15"
  }

  var currentBuild: String {
    Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "105"
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

struct GitHubReleaseMetadata: Decodable {
  let version: String
  let build: Int
  let platform: String?
  let minimumOS: String?
  let summary: String
  let downloadURL: URL
  let releaseNotesURL: URL?
  let publishedAt: Date?
  let changes: GitHubReleaseChanges?

  enum CodingKeys: String, CodingKey {
    case version
    case build
    case platform
    case minimumOS = "minimum_os"
    case summary
    case downloadURL = "download_url"
    case releaseNotesURL = "release_notes_url"
    case publishedAt = "published_at"
    case changes
  }

  var identifier: String {
    "\(version)-\(build)"
  }

  var displayVersion: String {
    "Version \(version) (\(build))"
  }
}

struct GitHubReleaseChanges: Decodable {
  let newFeatures: [String]
  let minorImprovements: [String]
  let bugFixes: [String]

  enum CodingKeys: String, CodingKey {
    case newFeatures = "new_features"
    case minorImprovements = "minor_improvements"
    case bugFixes = "bug_fixes"
  }
}

@MainActor
@Observable
final class GitHubUpgradeManager {
  static let shared = GitHubUpgradeManager()

  private let defaults = UserDefaults.standard
  private let lastDismissedReleaseKey = "lastDismissedGitHubRelease"
  private var isChecking = false

  var availableRelease: GitHubReleaseMetadata?
  var shouldShowUpgradeAlert = false

  private init() {}

  func checkForUpdates() {
    guard !isChecking, let feedURL = Self.updateFeedURL else { return }

    isChecking = true
    let currentVersion = currentVersion
    let currentBuild = currentBuild
    let lastDismissed = defaults.string(forKey: lastDismissedReleaseKey)

    Task {
      let release = await Self.fetchRelease(from: feedURL)
      await MainActor.run {
        self.isChecking = false

        guard
          let release,
          Self.isNewer(remoteVersion: release.version, remoteBuild: release.build, currentVersion: currentVersion, currentBuild: currentBuild),
          release.identifier != lastDismissed
        else {
          return
        }

        self.availableRelease = release
        self.shouldShowUpgradeAlert = true
      }
    }
  }

  func dismissCurrentUpgrade() {
    if let availableRelease {
      defaults.set(availableRelease.identifier, forKey: lastDismissedReleaseKey)
    }
    shouldShowUpgradeAlert = false
  }

  func openDownload() {
    guard let url = availableRelease?.downloadURL else { return }
    open(url)
  }

  func openReleaseNotes() {
    guard let url = availableRelease?.releaseNotesURL else { return }
    open(url)
  }

  private var currentVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.9.15"
  }

  private var currentBuild: Int {
    Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "100") ?? 100
  }

  private static var updateFeedURL: URL? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: "GTIMER_UPDATE_FEED_URL") as? String
    else {
      return nil
    }

    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme == "https" else {
      return nil
    }

    return url
  }

  nonisolated private static func fetchRelease(from url: URL) async -> GitHubReleaseMetadata? {
    do {
      let (data, response) = try await URLSession.shared.data(from: url)
      guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
        return nil
      }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      return try decoder.decode(GitHubReleaseMetadata.self, from: data)
    } catch {
      return nil
    }
  }

  nonisolated private static func isNewer(
    remoteVersion: String,
    remoteBuild: Int,
    currentVersion: String,
    currentBuild: Int
  ) -> Bool {
    let versionComparison = remoteVersion.compare(currentVersion, options: .numeric)
    if versionComparison == .orderedDescending {
      return true
    }
    if versionComparison == .orderedSame {
      return remoteBuild > currentBuild
    }
    return false
  }

  private func open(_ url: URL) {
    #if os(iOS)
    UIApplication.shared.open(url)
    #elseif os(macOS)
    NSWorkspace.shared.open(url)
    #endif
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
