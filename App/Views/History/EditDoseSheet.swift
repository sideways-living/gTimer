import SwiftUI
import SwiftData

struct EditDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context

  var dose: DoseRecord

  var body: some View {
    DoseFormSheet(
      kind: .edit,
      title: "Edit Dose",
      submitTitle: "Save Changes",
      initialAmount: dose.amount,
      initialTime: dose.time,
      initialNotes: dose.notes,
      initialLocationName: dose.locationName,
      initialLatitude: dose.latitude,
      initialLongitude: dose.longitude
    ) { result in
      dose.amount = result.amount
      dose.time = result.time
      dose.notes = result.notes
      dose.edited = true

      if result.location.isEmpty {
        dose.locationName = nil
        dose.latitude = nil
        dose.longitude = nil
        dose.locationAccuracyMeters = nil
        dose.locationCapturedAt = nil
        dose.locationSource = "none"
      } else {
        dose.locationName = result.location.name.isEmpty ? nil : result.location.name
        dose.latitude = result.location.coordinate?.latitude
        dose.longitude = result.location.coordinate?.longitude
        dose.locationAccuracyMeters = result.location.accuracyMeters
        dose.locationCapturedAt = result.location.capturedAt
        dose.locationSource = result.location.source
      }

      try? context.save()
      DoseStore.backfillMissingEarlyDoseTiming(context: context, settings: settings)
      DoseStore.refreshSharedAfterEdit(context: context, settings: settings)
    }
  }
}
