import SwiftUI
import PhotosUI

@Observable
final class SettingsManager {
  static let shared = SettingsManager()

  var standardDose: Double {
    didSet { UserDefaults.standard.set(standardDose, forKey: "standardDose") }
  }
  var unit: String {
    didSet { UserDefaults.standard.set(unit, forKey: "unit") }
  }
  var safeIntervalMinutes: Int {
    didSet {
      UserDefaults.standard.set(safeIntervalMinutes, forKey: "safeIntervalMinutes")
      updateShared()
    }
  }
  var substance: String {
    didSet { UserDefaults.standard.set(substance, forKey: "substance") }
  }
  var quickAmounts: [Double] {
    didSet {
      if let data = try? JSONEncoder().encode(quickAmounts) {
        UserDefaults.standard.set(data, forKey: "quickAmounts")
      }
    }
  }
  var notificationsEnabled: Bool {
    didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
  }
  var countdownMode: Bool {
    didSet { UserDefaults.standard.set(countdownMode, forKey: "countdownMode") }
  }
  var timeFormat: String {
    didSet { UserDefaults.standard.set(timeFormat, forKey: "timeFormat") }
  }
  var syncEnabled: Bool {
    didSet { UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled") }
  }
  var deviceName: String {
    didSet { UserDefaults.standard.set(deviceName, forKey: "deviceName") }
  }
  var vanityName: String {
    didSet { UserDefaults.standard.set(vanityName, forKey: "vanityName") }
  }
  var proBetaAccepted: Bool {
    didSet { UserDefaults.standard.set(proBetaAccepted, forKey: "proBetaAccepted") }
  }
  var profilePictureData: Data? {
    didSet { UserDefaults.standard.set(profilePictureData, forKey: "profilePictureData") }
  }

  init() {
    let ud = UserDefaults.standard
    standardDose      = ud.object(forKey: "standardDose") as? Double ?? 1.5
    unit              = ud.string(forKey: "unit") ?? "ml"
    safeIntervalMinutes = ud.object(forKey: "safeIntervalMinutes") as? Int ?? 90
    substance         = ud.string(forKey: "substance") ?? "GHB"
    notificationsEnabled = ud.bool(forKey: "notificationsEnabled")
    countdownMode     = ud.object(forKey: "countdownMode") as? Bool ?? true
    timeFormat        = ud.string(forKey: "timeFormat") ?? "hours"
    syncEnabled       = ud.bool(forKey: "syncEnabled")
    deviceName        = ud.string(forKey: "deviceName") ?? UIDevice.current.name
    vanityName        = ud.string(forKey: "vanityName") ?? ""
    proBetaAccepted   = ud.bool(forKey: "proBetaAccepted")
    profilePictureData = ud.data(forKey: "profilePictureData")

    if let data = ud.data(forKey: "quickAmounts"),
       let decoded = try? JSONDecoder().decode([Double].self, from: data) {
      quickAmounts = decoded
    } else {
      quickAmounts = [0.5, 1.0, 1.5, 2.0]
    }
  }

  private func updateShared() {
    // Shared defaults updated by DoseStore when dose is logged
  }
}
