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
