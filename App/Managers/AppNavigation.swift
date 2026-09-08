import SwiftUI

enum SettingsScrollTarget: Hashable {
  case quickAmounts
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
    selectedTab = 2
  }

  func openSettings() {
    selectedTab = 3
  }

  func openPro() {
    selectedTab = 4
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
    selectedTab = 1
    doseMapRequestID += 1
  }

  func requestQuitConfirmation() {
    shouldShowQuitWarning = true
  }
}
