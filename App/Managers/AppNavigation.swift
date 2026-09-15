import SwiftUI

enum SettingsScrollTarget: Hashable {
  case doseDefaults
  case safeInterval
  case quickAmounts
  case notifications
  case account
  case privacy
  case device
  case sync
  case doseLocations
  case homeLocation
  case display
  case colours
  case assistedDoseLogging
  case profile
}

enum HistoryExportOutcome {
  case export
  case print
}

@Observable
final class AppNavigation {
  static let shared = AppNavigation()
  var selectedTab: Int = 0
  var settingsScrollTarget: SettingsScrollTarget?
  var newDoseRequestID = 0
  var historyExportRequestID = 0
  var historyExportOutcome: HistoryExportOutcome = .export
  var doseMapRequestID = 0
  var shouldShowQuitWarning = false
  var settingsHasUnsavedChanges = false
  var blockedSettingsTabRequest: Int?
  var settingsNavigationPromptID = 0

  func selectTab(_ tab: Int) {
    if selectedTab == 4, tab != 4, settingsHasUnsavedChanges {
      blockedSettingsTabRequest = tab
      settingsNavigationPromptID += 1
      return
    }
    selectedTab = tab
  }

  func openTimer() {
    selectTab(0)
  }

  func openHistory() {
    selectTab(1)
  }

  func openHealth() {
    selectTab(3)
  }

  func openSettings(_ target: SettingsScrollTarget? = nil) {
    settingsScrollTarget = target
    selectedTab = 4
  }

  func openPro() {
    selectTab(5)
  }

  func requestNewDose() {
    selectTab(0)
    newDoseRequestID += 1
  }

  func requestHistoryExport(outcome: HistoryExportOutcome) {
    selectTab(1)
    historyExportOutcome = outcome
    historyExportRequestID += 1
  }

  func requestDoseMap() {
    selectTab(2)
    doseMapRequestID += 1
  }

  func requestQuitConfirmation() {
    shouldShowQuitWarning = true
  }
}
