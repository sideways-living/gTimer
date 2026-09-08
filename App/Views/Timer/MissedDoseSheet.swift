import SwiftUI

struct MissedDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context

  var body: some View {
    DoseFormSheet(
      kind: .missed,
      title: "Missed Dose",
      submitTitle: "Log Missed Dose",
      initialAmount: settings.standardDose,
      initialTime: Date(),
      initialNotes: "Missed dose",
      initialLocationName: nil,
      initialLatitude: nil,
      initialLongitude: nil
    ) { result in
      DoseStore.logDose(
        amount: result.amount,
        unit: settings.unit,
        time: result.time,
        notes: result.notes,
        missed: true,
        capturedLocation: result.location.clLocation,
        locationName: result.location.name.isEmpty ? nil : result.location.name,
        locationSource: result.location.isEmpty ? "none" : result.location.source,
        deviceName: settings.deviceName,
        context: context,
        settings: settings
      )
    }
  }
}
