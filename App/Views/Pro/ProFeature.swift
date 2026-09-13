import SwiftUI

enum ProFeature: String, CaseIterable {
  case fullHistory
  case editDose
  case exportHistory
  case missedDose
  case doseLocations
  case doseMap
  case locationInsights
  case deviceSync
  case profile

  var title: String {
    switch self {
    case .fullHistory:      return "Full Dose History"
    case .editDose:         return "Edit Doses"
    case .exportHistory:    return "Export History"
    case .missedDose:       return "Log Missed Doses"
    case .doseLocations:    return "Dose Locations"
    case .doseMap:          return "Dose Map"
    case .locationInsights: return "Location Insights"
    case .deviceSync:       return "Device Sync"
    case .profile:          return "Profile"
    }
  }

  var featureDescription: String {
    switch self {
    case .fullHistory:
      return "Keep your complete dose history, not just the last 24 hours."
    case .editDose:
      return "Correct amount, time, notes, and location when something was logged wrong."
    case .exportHistory:
      return "Export your full history as CSV, including optional location fields."
    case .missedDose:
      return "Log doses you forgot to record, with the correct time and optional location."
    case .doseLocations:
      return "Attach private location context to doses. All location data stays on this device."
    case .doseMap:
      return "See where doses were logged and spot patterns that may help you make safer choices."
    case .locationInsights:
      return "Understand your dose patterns across locations to make more informed choices."
    case .deviceSync:
      return "Keep dose history in sync across your signed-in devices."
    case .profile:
      return "Set a display name and profile photo."
    }
  }

  var icon: String {
    switch self {
    case .fullHistory:      return "clock.arrow.circlepath"
    case .editDose:         return "pencil.circle.fill"
    case .exportHistory:    return "square.and.arrow.up"
    case .missedDose:       return "xmark.circle.fill"
    case .doseLocations:    return "location.fill"
    case .doseMap:          return "map.fill"
    case .locationInsights: return "chart.bar.fill"
    case .deviceSync:       return "icloud.fill"
    case .profile:          return "person.crop.circle.fill"
    }
  }

  var accentColor: Color {
    switch self {
    case .doseLocations, .doseMap, .locationInsights, .deviceSync:
      return AppTheme.accentBlue
    default:
      return AppTheme.proAmber
    }
  }
}

// Session-scoped dismissal throttle — prevents the same paywall from
// re-appearing immediately after the user dismisses it.
@Observable
final class PaywallThrottle {
  static let shared = PaywallThrottle()
  private var dismissed: Set<String> = []

  func wasDismissed(_ feature: ProFeature) -> Bool {
    dismissed.contains(feature.rawValue)
  }

  func markDismissed(_ feature: ProFeature) {
    dismissed.insert(feature.rawValue)
  }
}
