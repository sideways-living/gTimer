import SwiftUI
import PhotosUI

struct SettingsView: View {
  @Environment(SettingsManager.self) private var settings
  @State private var showUnsavedAlert = false
  @State private var customIntervalText = ""
  @State private var standardDoseText = ""
  @State private var deviceNameText = ""
  @State private var vanityNameText = ""
  @State private var hasChanges = false
  @State private var photoPickerItem: PhotosPickerItem?
  @State private var quickAmountsText = ""
  @State private var quickAmountsError = false

  private let intervalPresets = [60, 90, 120]

  private var saveButtonColor: Color {
    hasChanges ? AppTheme.accentBlue : AppTheme.textMuted
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 16) {
            doseSection
            intervalSection
            quickAmountsSection
            displaySection
            notificationsSection
            deviceSection
            if settings.proBetaAccepted { profileSection }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 16)
          .padding(.bottom, 90)
        }
      }
      .navigationTitle("Settings")
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Save") { saveAll() }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(saveButtonColor)
            .disabled(!hasChanges)
        }
      }
      .alert("Unsaved Changes", isPresented: $showUnsavedAlert) {
        Button("Discard", role: .destructive) { reloadFromSettings() }
        Button("Keep Editing", role: .cancel) {}
      }
    }
    .preferredColorScheme(.dark)
    .onAppear { reloadFromSettings() }
    .onChange(of: standardDoseText) { hasChanges = true }
    .onChange(of: deviceNameText) { hasChanges = true }
    .onChange(of: vanityNameText) { hasChanges = true }
    .onChange(of: quickAmountsText) { hasChanges = true; quickAmountsError = false }
    .onChange(of: customIntervalText) { hasChanges = true }
    .onChange(of: photoPickerItem) { loadPhoto() }
  }

  // MARK: - Sections

  private var doseSection: some View {
    settingsCard(title: "Dose Defaults") {
      VStack(spacing: 0) {
        row(label: "Standard dose") {
          HStack(spacing: 4) {
            TextField("1.5", text: $standardDoseText)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
              .font(.system(size: 16))
              .foregroundStyle(AppTheme.textPrimary)
              .frame(width: 60)
            Text(settings.unit)
              .foregroundStyle(AppTheme.textSecondary)
              .font(.system(size: 15))
          }
        }
        divider
        row(label: "Unit") {
          @Bindable var s = settings
          Picker("Unit", selection: $s.unit) {
            Text("ml").tag("ml")
            Text("g").tag("g")
            Text("mg").tag("mg")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.unit) { hasChanges = true }
        }
        divider
        row(label: "Substance") {
          @Bindable var s = settings
          Picker("Substance", selection: $s.substance) {
            Text("GHB").tag("GHB")
            Text("GBL").tag("GBL")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.substance) { hasChanges = true }
        }
      }
    }
  }

  private var intervalSection: some View {
    settingsCard(title: "Safe Interval") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
          ForEach(intervalPresets, id: \.self) { preset in
            let isSelected = settings.safeIntervalMinutes == preset && customIntervalText.isEmpty
            Button {
              settings.safeIntervalMinutes = preset
              customIntervalText = ""
              hasChanges = true
            } label: {
              Text("\(preset)m")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : AppTheme.accentBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(isSelected ? AppTheme.accentBlue : AppTheme.accentBlue.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
          }
        }

        HStack {
          Text("Custom (minutes)")
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textSecondary)
          Spacer()
          TextField("e.g. 105", text: $customIntervalText)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 16))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(width: 80)
        }
        .padding(12)
        .background(AppTheme.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 9))
      }
    }
  }

  private var quickAmountsSection: some View {
    settingsCard(title: "Quick Amounts") {
      VStack(alignment: .leading, spacing: 10) {
        TextField("0.5, 1.0, 1.5, 2.0", text: $quickAmountsText)
          .keyboardType(.numbersAndPunctuation)
          .font(.system(size: 15))
          .foregroundStyle(AppTheme.textPrimary)
          .padding(12)
          .background(AppTheme.backgroundElevated)
          .clipShape(RoundedRectangle(cornerRadius: 9))
          .overlay(
            RoundedRectangle(cornerRadius: 9)
              .stroke(quickAmountsError ? AppTheme.statusRed : Color.clear, lineWidth: 1)
          )

        if quickAmountsError {
          Text("All values must be positive numbers, separated by commas.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusRed)
        } else {
          Text("Comma-separated amounts — e.g. 0.5, 1.0, 1.5, 2.0")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
        }
      }
    }
  }

  private var displaySection: some View {
    settingsCard(title: "Display") {
      VStack(spacing: 0) {
        row(label: "Timer mode") {
          @Bindable var s = settings
          Picker("Timer mode", selection: $s.countdownMode) {
            Text("Countdown").tag(true)
            Text("Count up").tag(false)
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.countdownMode) { hasChanges = true }
        }
        divider
        row(label: "Time format") {
          @Bindable var s = settings
          Picker("Format", selection: $s.timeFormat) {
            Text("HH:MM:SS").tag("hours")
            Text("MM:SS").tag("minutes")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.timeFormat) { hasChanges = true }
        }
      }
    }
  }

  private var notificationsSection: some View {
    settingsCard(title: "Notifications") {
      VStack(spacing: 10) {
        row(label: "Safe to redose reminder") {
          @Bindable var s = settings
          Toggle("", isOn: $s.notificationsEnabled)
            .tint(AppTheme.accentBlue)
            .onChange(of: settings.notificationsEnabled) {
              hasChanges = true
              if settings.notificationsEnabled {
                Task { await NotificationManager.shared.requestPermission() }
              }
            }
        }
        if settings.notificationsEnabled {
          Text("You'll receive a notification when your safe interval has passed.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  private var deviceSection: some View {
    settingsCard(title: "Device") {
      row(label: "Device name") {
        TextField("My iPhone", text: $deviceNameText)
          .multilineTextAlignment(.trailing)
          .font(.system(size: 15))
          .foregroundStyle(AppTheme.textPrimary)
          .frame(maxWidth: 180)
      }
    }
  }

  private var profileSection: some View {
    settingsCard(title: "Profile (Pro)") {
      VStack(spacing: 14) {
        HStack(spacing: 14) {
          if let data = settings.profilePictureData, let img = UIImage(data: data) {
            Image(uiImage: img)
              .resizable()
              .scaledToFill()
              .frame(width: 52, height: 52)
              .clipShape(Circle())
              .overlay(Circle().stroke(AppTheme.proAmber, lineWidth: 2))
          } else {
            ZStack {
              Circle()
                .fill(AppTheme.backgroundElevated)
                .frame(width: 52, height: 52)
              Image(systemName: "person.fill")
                .foregroundStyle(AppTheme.textMuted)
                .font(.system(size: 22))
            }
          }
          VStack(alignment: .leading, spacing: 4) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
              Text("Change Photo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.proAmber)
            }
            .accessibilityLabel("Change profile photo")
            Text("JPG or PNG, shown in the Pro tab")
              .font(.system(size: 11))
              .foregroundStyle(AppTheme.textMuted)
          }
          Spacer()
        }

        divider

        row(label: "Display name") {
          TextField("Your name", text: $vanityNameText)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: 180)
        }
      }
    }
  }

  // MARK: - Helpers

  private var divider: some View {
    Divider()
      .background(AppTheme.border)
      .padding(.vertical, 4)
  }

  private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AppTheme.textMuted)
        .kerning(0.3)
        .padding(.leading, 4)
      content()
        .padding(14)
        .background(AppTheme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 0.5))
    }
  }

  private func row<Content: View>(label: String, @ViewBuilder trailing: () -> Content) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textPrimary)
      Spacer()
      trailing()
    }
    .padding(.vertical, 2)
  }

  // MARK: - Save / discard

  private func saveAll() {
    // Validate quick amounts
    let parsed = quickAmountsText
      .split(separator: ",")
      .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
      .filter { $0 > 0 }

    let inputCount = quickAmountsText
      .split(separator: ",")
      .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
      .count

    if inputCount > 0 && parsed.count != inputCount {
      quickAmountsError = true
      return
    }

    if let d = Double(standardDoseText), d > 0 { settings.standardDose = d }
    settings.deviceName = deviceNameText
    settings.vanityName = vanityNameText

    if let minutes = Int(customIntervalText), minutes > 0 {
      settings.safeIntervalMinutes = minutes
    }
    if !parsed.isEmpty { settings.quickAmounts = parsed }

    hasChanges = false
    quickAmountsError = false
  }

  private func reloadFromSettings() {
    standardDoseText = settings.standardDose.formatted(.number.precision(.fractionLength(1)))
    deviceNameText = settings.deviceName
    vanityNameText = settings.vanityName
    quickAmountsText = settings.quickAmounts
      .map { $0.formatted(.number.precision(.fractionLength(1))) }
      .joined(separator: ", ")
    customIntervalText = ""
    hasChanges = false
    quickAmountsError = false
  }

  private func loadPhoto() {
    guard let item = photoPickerItem else { return }
    Task {
      if let data = try? await item.loadTransferable(type: Data.self) {
        settings.profilePictureData = data
        hasChanges = true
      }
    }
  }
}
