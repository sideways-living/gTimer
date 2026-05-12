import SwiftUI

// Native tab bar (49pt) + home-indicator safe area (34pt) + breathing room = 150pt.
// Apply this to every ScrollView that lives inside a tab so its bottom content
// clears the tab bar entirely, including on smaller devices.
private let kTabBarClearance: CGFloat = 150

extension View {
  func tabBarScrollClearance() -> some View {
    self.contentMargins(.bottom, kTabBarClearance, for: .scrollContent)
  }
}
