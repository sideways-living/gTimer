import SwiftUI
import PhotosUI
import WidgetKit

enum SaveState { case idle, unsaved, saved }

struct SettingsView: View {
  @Environment(SettingsManager.self) private var settings
  @State private var saveState: SaveState = .idle
  @State private var customIntervalText = ""
  @State private var standardDoseText = ""
  @State private var deviceNameText = ""
  @State private var vanityNameText = ""
  @State private var photoPickerItem: PhotosPickerItem?
  @State private var quickAmountsText = ""
  @State private var quickAmountsError: String? = nil
  @State private var intervalError: String? = nil
  @State private var hasLoaded = false

  private let intervalPresets = [60, 90, 120]
  private var hasChanges: Bool { saveState == .unsaved }

  var body: some View {
    NavigationStack {
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
        .padding(.top, 16)
      }
      .tabBarScrollClearance()
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
      .navigationTitle("Settings")
      .toolbarBackground(AppTheme.backgroundSecondary, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          saveButton
        }
      }
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .onAppear { reloadFromSettings() }
    .onChange(of: standardDoseText) { markUnsaved() }
    .onChange(of: deviceNameText) { markUnsaved() }
    .onChange(of: vanityNameText) { markUnsaved() }
    .onChange(of: quickAmountsText) { markUnsaved(); quickAmountsError = nil }
    .onChange(of: customIntervalText) { markUnsaved(); intervalError = nil }
    .onChange(of: photoPickerItem) { loadPhoto() }
  }

  // MARK: - Save button (3 states)

  @ViewBuilder
  private var saveButton: some View {
    switch saveState {
    case .idle:
      Text("Save")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(AppTheme.textMuted)
    case .unsaved:
      Button("Save") { saveAll() }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(AppTheme.accentBlue)
    case .saved:
      HStack(spacing: 4) {
        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
        Text("Saved")
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(AppTheme.statusGreen)
    }
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
        cardDivider
        row(label: "Unit") {
          @Bindable var s = settings
          Picker("Unit", selection: $s.unit) {
            Text("ml").tag("ml")
            Text("g").tag("g")
            Text("mg").tag("mg")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.unit) { markUnsaved() }
        }
        cardDivider
        row(label: "Substance") {
          @Bindable var s = settings
          Picker("Substance", selection: $s.substance) {
            Text("GHB").tag("GHB")
            Text("GBL").tag("GBL")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.substance) { markUnsaved() }
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
              intervalError = nil
              markUnsaved()
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

        VStack(alignment: .leading, spacing: 6) {
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
          .overlay(
            RoundedRectangle(cornerRadius: 9)
              .stroke(intervalError != nil ? AppTheme.statusRed : Color.clear, lineWidth: 1)
          )

          if let err = intervalError {
            Text(err)
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.statusRed)
          }
        }
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
              .stroke(quickAmountsError != nil ? AppTheme.statusRed : Color.clear, lineWidth: 1)
          )

        if let err = quickAmountsError {
          Text(err).font(.system(size: 12)).foregroundStyle(AppTheme.statusRed)
        } else {
          Text("Four comma-separated amounts — e.g. 0.5, 1.0, 1.5, 2.0")
            .font(.system(size: 12)).foregroundStyle(AppTheme.textMuted)
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
          .onChange(of: settings.countdownMode) { markUnsaved() }
        }
        cardDivider
        row(label: "Time format") {
          @Bindable var s = settings
          Picker("Format", selection: $s.timeFormat) {
            Text("HH:MM:SS").tag("hours")
            Text("MM:SS").tag("minutes")
          }
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .onChange(of: settings.timeFormat) { markUnsaved() }
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
              markUnsaved()
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
              .resizable().scaledToFill()
              .frame(width: 52, height: 52).clipShape(Circle())
              .overlay(Circle().stroke(AppTheme.proAmber, lineWidth: 2))
          } else {
            ZStack {
              Circle().fill(AppTheme.backgroundElevated).frame(width: 52, height: 52)
              Image(systemName: "person.fill").foregroundStyle(AppTheme.textMuted).font(.system(size: 22))
            }
          }
          VStack(alignment: .leading, spacing: 4) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
              Text("Change Photo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.proAmber)
            }
            .accessibilityLabel("Change profile photo")
            Text("Shown in the Pro tab")
              .font(.system(size: 11))
              .foregroundStyle(AppTheme.textMuted)
          }
          Spacer()
        }
        cardDivider
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

  // MARK: - Shared helpers

  private var cardDivider: some View {
    Divider().background(AppTheme.border).padding(.vertical, 4)
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
      Text(label).font(.system(size: 15)).foregroundStyle(AppTheme.textPrimary)
      Spacer()
      trailing()
    }
    .padding(.vertical, 2)
  }

  // MARK: - Save / validate

  private func markUnsaved() {
    guard hasLoaded else { return }
    if saveState != .unsaved { saveState = .unsaved }
  }

  private func saveAll() {
    // Validate quick amounts: exactly 4 positive numbers
    let parts = quickAmountsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    let parsed = parts.compactMap { Double($0) }.filter { $0 > 0 }
    if parts.count != 4 || parsed.count != 4 {
      quickAmountsError = "Enter exactly four positive numbers, e.g. 0.5, 1.0, 1.5, 2.0"
      return
    }

    // Validate custom interval
    if !customIntervalText.isEmpty {
      guard let minutes = Int(customIntervalText), minutes >= 15 else {
        intervalError = "Minimum interval is 15 minutes."
        return
      }
      settings.safeIntervalMinutes = minutes
    }

    if let d = Double(standardDoseText), d > 0 { settings.standardDose = d }
    settings.deviceName = deviceNameText
    settings.vanityName = vanityNameText
    settings.quickAmounts = parsed

    quickAmountsError = nil
    intervalError = nil
    saveState = .saved
    WidgetCenter.shared.reloadAllTimelines()

    // Reset to idle after a moment
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
      if saveState == .saved { saveState = .idle }
    }
  }

  private func reloadFromSettings() {
    hasLoaded = false
    standardDoseText = settings.standardDose.formatted(.number.precision(.fractionLength(1)))
    deviceNameText = settings.deviceName
    vanityNameText = settings.vanityName
    quickAmountsText = settings.quickAmounts
      .map { $0.formatted(.number.precision(.fractionLength(1))) }
      .joined(separator: ", ")
    customIntervalText = ""
    saveState = .idle
    quickAmountsError = nil
    intervalError = nil
    Task { @MainActor in hasLoaded = true }
  }

  private func loadPhoto() {
    guard let item = photoPickerItem else { return }
    Task {
      if let data = try? await item.loadTransferable(type: Data.self) {
        settings.profilePictureData = data
        markUnsaved()
      }
    }
  }
}
