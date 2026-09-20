import Foundation

enum AppGroup {
  // TODO: When distributing outside the Bitrig simulator, replace this identifier
  // with the App Group you register in the Apple Developer portal
  // (Certificates, Identifiers & Profiles → Identifiers → App Groups).
  // The same string must appear in the entitlements of BOTH the "gTimer" app
  // target AND the "gTimer Widget Extension" target in Project.json.
  static let id = "group.app.bitrig.new.cc0b1024-f41a-488c-b5dd-b6845c513c01"
  static let sharedDefaults = UserDefaults(suiteName: id)
  static let lastDoseKey = "lastDoseData"
}

enum AppPreferences {
  private static let schemaVersionKey = "settingsCanonicalSchemaVersion"
  private static let schemaVersion = 1

  static var defaults: UserDefaults {
    AppGroup.sharedDefaults ?? .standard
  }

  static func prepare() {
    let canonical = defaults
    guard canonical.integer(forKey: schemaVersionKey) < schemaVersion else { return }

    // Existing installs historically stored settings in the app's standard
    // domain. Seed the App Group once so signed, packaged, and debug builds use
    // the same durable settings thereafter.
    for key in settingKeys where canonical.object(forKey: key) == nil {
      if let value = UserDefaults.standard.object(forKey: key) {
        canonical.set(value, forKey: key)
      }
    }
    canonical.set(schemaVersion, forKey: schemaVersionKey)
  }

  static func set(_ value: Any?, forKey key: String) {
    defaults.set(value, forKey: key)
    UserDefaults.standard.set(value, forKey: key)
  }

  static func removeObject(forKey key: String) {
    defaults.removeObject(forKey: key)
    UserDefaults.standard.removeObject(forKey: key)
  }

  private static let settingKeys = [
    "standardDose", "unit", "safeIntervalMinutes", "substance", "quickAmounts",
    "notificationsEnabled", "lockScreenNotificationsEnabled", "countdownMode",
    "timeFormat", "showSafeElapsedTimer", "includeDeletedDosesInHistory",
    "voiceDoseLoggingEnabled", "voiceDoseAttachCurrentLocation",
    "voiceDoseMatchSavedLocations", "voiceDoseStoreSpokenPhraseInNotes",
    "syncEnabled", "syncServerURL", "syncAccountEmail", "syncDeviceID",
    "deviceInstallID", "accountSetupCompleted", "accountName", "accountEmail",
    "historyPinEnabled", "syncTrialStartedAt", "syncCursor", "lastSyncAt",
    "syncStatusMessage",
    "deviceName", "vanityName", "proBetaAccepted", "profilePictureData",
    "attachLocationToDoses", "locationApproximate", "homeCity", "homeCountryCode",
    "homeAddress", "homeLatitude", "homeLongitude", "appearanceMode",
    "customAccentHex", "customPrimaryButtonHex", "customQuickButtonHex",
    "customBackgroundHex", "manualDoseLocations"
  ]
}
