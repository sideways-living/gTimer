import SwiftUI
#if os(iOS)
import UIKit
#endif

// Native tab bar (49pt) + home-indicator safe area (34pt) + breathing room = 150pt.
// Apply this to every ScrollView that lives inside a tab so its bottom content
// clears the tab bar entirely, including on smaller devices.
private let kTabBarClearance: CGFloat = 180

#if os(iOS)
typealias PlatformKeyboardType = UIKeyboardType
typealias PlatformTextContentType = UITextContentType
#else
enum PlatformKeyboardType {
  case `default`
  case decimalPad
  case numberPad
  case emailAddress
}

enum PlatformTextContentType {
  case givenName
  case familyName
  case emailAddress
}
#endif

extension View {
  func tabBarScrollClearance() -> some View {
    self.contentMargins(.bottom, kTabBarClearance, for: .scrollContent)
  }

  @ViewBuilder
  func platformKeyboardType(_ type: PlatformKeyboardType) -> some View {
    #if os(iOS)
    self.keyboardType(type)
    #else
    self
    #endif
  }

  @ViewBuilder
  func platformTextContentType(_ type: PlatformTextContentType?) -> some View {
    #if os(iOS)
    self.textContentType(type)
    #else
    self
    #endif
  }

  @ViewBuilder
  func platformNavigationBarStyle() -> some View {
    #if os(iOS)
    self
      .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
    #else
    self
    #endif
  }

  @ViewBuilder
  func platformInlineNavigationTitle() -> some View {
    #if os(iOS)
    self.navigationBarTitleDisplayMode(.inline)
    #else
    self
    #endif
  }
}
