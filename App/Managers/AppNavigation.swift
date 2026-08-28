import SwiftUI

enum SettingsScrollTarget: Hashable {
  case quickAmounts
}

@Observable
final class AppNavigation {
  static let shared = AppNavigation()
  var selectedTab: Int = 0
  var settingsScrollTarget: SettingsScrollTarget?
}
