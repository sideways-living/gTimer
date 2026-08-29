import SwiftUI
import CoreLocation

struct MissedDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @State private var amountText = "1.5"
  @State private var selectedDate = Date()
  @State private var notes = ""
  @State private var attachLocation = false
  @State private var isLogging = false

  private var locationAvailable: Bool {
    settings.attachLocationToDoses &&
      LocationManager.shared.hasLocationPermission
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        VStack(spacing: 20) {
          infoBox

          VStack(alignment: .leading, spacing: 8) {
            Text("Amount (\(settings.unit))")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textSecondary)
            TextField("Amount", text: $amountText)
              .platformKeyboardType(.decimalPad)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(AppTheme.textPrimary)
              .padding(14)
              .background(AppTheme.backgroundCard)
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("When did you take it?")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textSecondary)
            DatePicker("Time", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
              .labelsHidden()
              .colorScheme(.dark)
              .padding(10)
              .background(AppTheme.backgroundCard)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }

          VStack(alignment: .leading, spacing: 8) {
            Text("Notes (optional)")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(AppTheme.textSecondary)
            TextField("Add a note…", text: $notes, axis: .vertical)
              .font(.system(size: 16))
              .foregroundStyle(AppTheme.textPrimary)
              .lineLimit(2...4)
              .padding(14)
              .background(AppTheme.backgroundCard)
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
          }

          // Location attachment (Pro only, shown when location permission exists)
          if settings.attachLocationToDoses {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text("Attach current location")
                  .font(.system(size: 15))
                  .foregroundStyle(AppTheme.textPrimary)
                Text("Logs your current position, not where you were then.")
                  .font(.system(size: 12))
                  .foregroundStyle(AppTheme.textMuted)
              }
              Spacer()
              Toggle("Attach current location", isOn: $attachLocation)
                .labelsHidden()
                .tint(AppTheme.accentBlue)
                .accessibilityLabel("Attach current location")
            }
            .padding(14)
            .background(AppTheme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
          }

          Spacer()

          Button {
            guard !isLogging else { return }
            isLogging = true
            let a = Double(amountText) ?? settings.standardDose
            let loc = LocationManager.shared

            if attachLocation && locationAvailable {
              Task { @MainActor in
                let captured = await loc.captureForDose()
                DoseStore.logDose(
                  amount: a,
                  unit: settings.unit,
                  time: selectedDate,
                  notes: notes,
                  missed: true,
                  capturedLocation: captured,
                  locationName: loc.locationName,
                  locationSource: "manual",
                  deviceName: settings.deviceName,
                  context: context,
                  settings: settings
                )
                dismiss()
              }
            } else {
              DoseStore.logDose(
                amount: a,
                unit: settings.unit,
                time: selectedDate,
                notes: notes,
                missed: true,
                deviceName: settings.deviceName,
                context: context,
                settings: settings
              )
              dismiss()
            }
          } label: {
            Text("Log Missed Dose")
              .font(.system(size: 17, weight: .semibold))
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 15)
              .background(AppTheme.proAmber)
              .clipShape(RoundedRectangle(cornerRadius: 14))
          }
          .disabled(isLogging)
        }
        .padding(20)
      }
      .navigationTitle("Missed Dose")
      .platformInlineNavigationTitle()
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
            .foregroundStyle(AppTheme.textSecondary)
        }
      }
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)
    .onAppear {
      amountText = settings.standardDose.formatted(.number.precision(.fractionLength(1)))
    }
  }

  private var infoBox: some View {
    HStack(spacing: 10) {
      Image(systemName: "info.circle.fill")
        .foregroundStyle(AppTheme.proAmber)
      Text("Use this to record a dose you forgot to log at the time.")
        .font(.system(size: 13))
        .foregroundStyle(AppTheme.textSecondary)
    }
    .padding(12)
    .background(AppTheme.proAmber.opacity(0.08))
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }
}
