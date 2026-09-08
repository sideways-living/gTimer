import SwiftUI

struct CustomDoseSheet: View {
  @Environment(SettingsManager.self) private var settings

  var onLog: (DoseFormResult) -> Void

  var body: some View {
    DoseFormSheet(
      kind: .add,
      title: "Add Dose",
      submitTitle: "Log Dose",
      initialAmount: settings.standardDose,
      initialTime: Date(),
      initialNotes: "",
      initialLocationName: nil,
      initialLatitude: nil,
      initialLongitude: nil,
      onSubmit: onLog
    )
  }
}
