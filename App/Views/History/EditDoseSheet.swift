import SwiftUI

struct EditDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  var dose: DoseRecord

  @State private var amountText: String = ""
  @State private var selectedDate: Date = Date()
  @State private var notes: String = ""
  @State private var locationNameText = ""
  @State private var latitudeText = ""
  @State private var longitudeText = ""
  @State private var locationError: String?
  @State private var isCapturingLocation = false
  @State private var showDiscard = false

  private var isDirty: Bool {
    let a = Double(amountText) ?? dose.amount
    return a != dose.amount ||
      selectedDate != dose.time ||
      notes != dose.notes ||
      locationNameText != (dose.locationName ?? "") ||
      latitudeText != coordinateText(dose.latitude) ||
      longitudeText != coordinateText(dose.longitude)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 20) {
          sheetHeader(title: "Edit Dose")

          field(label: "Amount (\(settings.unit))") {
            TextField("Amount", text: $amountText)
              .platformKeyboardType(.decimalPad)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(AppTheme.textPrimary)
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Date & Time")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textSecondary)
            DatePicker("Date & Time", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
              .labelsHidden()
              .colorScheme(.dark)
              .padding(10)
              .background(AppTheme.backgroundCard)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          field(label: "Notes") {
            TextField("Notes", text: $notes, axis: .vertical)
              .font(.system(size: 16))
              .foregroundStyle(AppTheme.textPrimary)
              .lineLimit(2...4)
          }

          locationEditor

          Spacer()

          Button {
            saveChanges()
          } label: {
            Text("Save Changes")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
              .background(AppTheme.accentBlue)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
        }
        .padding(20)
      }
      .navigationTitle("Edit Dose")
      .platformInlineNavigationTitle()
      .confirmationDialog("Discard changes?", isPresented: $showDiscard, titleVisibility: .visible) {
        Button("Discard", role: .destructive) { dismiss() }
        Button("Keep Editing", role: .cancel) {}
      }
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)
    .onAppear {
      amountText = dose.amount.formatted(.number.precision(.fractionLength(1)))
      selectedDate = dose.time
      notes = dose.notes
      locationNameText = dose.locationName ?? ""
      latitudeText = coordinateText(dose.latitude)
      longitudeText = coordinateText(dose.longitude)
    }
  }

  private var locationEditor: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Location")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(AppTheme.textSecondary)
        Spacer()
        if dose.hasLocation || !locationNameText.isEmpty || !latitudeText.isEmpty || !longitudeText.isEmpty {
          Button("Remove") {
            locationNameText = ""
            latitudeText = ""
            longitudeText = ""
            locationError = nil
          }
          .buttonStyle(.plain)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(AppTheme.statusRed)
        }
      }

      TextField("Location name or address", text: $locationNameText)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textPrimary)
        .padding(12)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))

      HStack(spacing: 10) {
        coordinateField("Latitude", text: $latitudeText)
        coordinateField("Longitude", text: $longitudeText)
      }

      Button {
        captureCurrentLocation()
      } label: {
        HStack(spacing: 8) {
          if isCapturingLocation {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: "location.fill")
              .font(.system(size: 12, weight: .semibold))
          }
          Text(isCapturingLocation ? "Getting location..." : "Use current location")
            .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(AppTheme.accentBlue)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppTheme.accentBlue.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .buttonStyle(.plain)
      .disabled(isCapturingLocation)

      if let locationError {
        Text(locationError)
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.statusAmber)
      }
    }
  }

  private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)
      content()
        .padding(14)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
    }
  }

  private func sheetHeader(title: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
      Spacer()
      Button {
        if isDirty { showDiscard = true } else { dismiss() }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.textSecondary)
          .frame(width: 32, height: 32)
          .background(AppTheme.backgroundCard)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Close")
    }
  }

  private func coordinateField(_ label: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.textMuted)
      TextField(label, text: text)
        .platformKeyboardType(.decimalPad)
        .font(.system(size: 14, design: .monospaced))
        .foregroundStyle(AppTheme.textPrimary)
        .padding(12)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
    }
  }

  private func captureCurrentLocation() {
    isCapturingLocation = true
    locationError = nil
    let loc = LocationManager.shared
    loc.requestWhenInUsePermission()
    Task { @MainActor in
      let captured = await loc.captureForDose()
      guard let captured else {
        isCapturingLocation = false
        locationError = "Current location was not available."
        return
      }
      latitudeText = coordinateText(captured.coordinate.latitude)
      longitudeText = coordinateText(captured.coordinate.longitude)
      if let name = loc.locationName, !name.isEmpty {
        locationNameText = name
      }
      isCapturingLocation = false
    }
  }

  private func saveChanges() {
    let a = Double(amountText) ?? dose.amount
    let cleanName = locationNameText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanLat = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanLon = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)

    if cleanLat.isEmpty && cleanLon.isEmpty {
      dose.latitude = nil
      dose.longitude = nil
      dose.locationName = cleanName.isEmpty ? nil : cleanName
      dose.locationAccuracyMeters = nil
      dose.locationCapturedAt = cleanName.isEmpty ? nil : Date()
      dose.locationSource = cleanName.isEmpty ? "none" : "manual"
    } else if
      let lat = Double(cleanLat),
      let lon = Double(cleanLon),
      (-90...90).contains(lat),
      (-180...180).contains(lon) {
      dose.latitude = lat
      dose.longitude = lon
      dose.locationName = cleanName.isEmpty ? nil : cleanName
      dose.locationAccuracyMeters = nil
      dose.locationCapturedAt = Date()
      dose.locationSource = "manual"
    } else {
      locationError = "Enter valid latitude and longitude, or leave both blank."
      return
    }

    dose.amount = a
    dose.time = selectedDate
    dose.notes = notes
    dose.edited = true
    try? context.save()
    DoseStore.refreshSharedAfterEdit(context: context, settings: settings)
    dismiss()
  }

  private func coordinateText(_ value: Double?) -> String {
    guard let value else { return "" }
    return String(format: "%.6f", value)
  }
}
