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

  func openTimer() {
    selectedTab = 0
  }

  func openHistory() {
    selectedTab = 1
  }

  func openHealth() {
    selectedTab = 3
  }

  func openSettings(_ target: SettingsScrollTarget? = nil) {
    settingsScrollTarget = target
    selectedTab = 4
  }

  func openPro() {
    selectedTab = 5
  }

  func requestNewDose() {
    selectedTab = 0
    newDoseRequestID += 1
  }

  func requestHistoryExport(outcome: HistoryExportOutcome) {
    selectedTab = 1
    historyExportOutcome = outcome
    historyExportRequestID += 1
  }

  func requestDoseMap() {
    selectedTab = 2
    doseMapRequestID += 1
  }

  func requestQuitConfirmation() {
    shouldShowQuitWarning = true
  }
}
