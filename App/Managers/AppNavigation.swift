import SwiftUI

@Observable
final class AppNavigation {
  static let shared = AppNavigation()
  var selectedTab: Int = 0
}
