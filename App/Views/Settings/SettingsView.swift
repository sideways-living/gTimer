import SwiftUI
import PhotosUI
import WidgetKit
import CoreLocation
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
import AVFoundation
#endif

enum SaveState { case idle, unsaved, saved }

struct SettingsView: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(AppNavigation.self) private var nav
  @Environment(\.openURL) private var openURL
  @Environment(\.modelContext) private var context
  @Query(sort: \DoseRecord.time, order: .reverse) private var doseRecords: [DoseRecord]
  @State private var saveState: SaveState = .idle
  @State private var customIntervalText = ""
  @State private var standardDoseText = ""
  @State private var deviceNameText = ""
  @State private var syncServerURLText = ""
  @State private var syncTokenText = ""
  @State private var syncEmailText = ""
  @State private var syncPasswordText = ""
  @State private var syncAuthMessage: String? = nil
  @State private var syncDevices: [SyncDevice] = []
  @State private var isSyncing = false
  @State private var isAuthenticatingSync = false
  @State private var vanityNameText = ""
  @State private var homeCityText = ""
  @State private var homeCountryCode = ""
  @State private var homeAddressText = ""
  @State private var homeLatitudeText = ""
  @State private var homeLongitudeText = ""
  @State private var homeLocationError: String? = nil
  @State private var homeLocationResults: [ManualDoseLocation] = []
  @State private var homeLocationSearchTask: Task<Void, Never>?
  @State private var isLookingUpHomeLocation = false
  @State private var suppressNextHomeLocationSearch = false
  @State private var photoPickerItem: PhotosPickerItem?
  @State private var showPhotoSourceDialog = false
  @State private var showPhotoPicker = false
  @State private var showFilePicker = false
  @State private var showCamera = false
  @State private var photoImportError: String? = nil
  @State private var quickAmountTexts = Array(repeating: "", count: 4)
  @State private var quickAmountsError: String? = nil
  @State private var intervalError: String? = nil
  @State private var notificationStatusMessage: String? = nil
  @State private var hasLoaded = false
  @State private var showPaywall = false
  @State private var paywallFeature: ProFeature = .doseLocations

  private let intervalPresets = [60, 90, 120]
  private var hasChanges: Bool { saveState == .unsaved }
  private var homeLocationSuggestions: [ManualDoseLocation] {
    ManualLocationStore.shared.suggestions(matching: homeAddressText, limit: 4)
  }
  private var canUseDeviceSync: Bool {
    settings.canUseDeviceSync
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            doseSection
            intervalSection
            quickAmountsSection
              .id(SettingsScrollTarget.quickAmounts)
            displaySection
            colourSection
            notificationsSection
            deviceSection
            syncSection
            locationSection
            homeLocationSection
            if settings.proBetaAccepted { profileSection }
          }
          .padding(.horizontal, 16)
          .padding(.top, 16)
        }
        .tabBarScrollClearance()
        .background(AppTheme.backgroundPrimary.ignoresSafeArea())
        .onAppear { scrollToRequestedSection(proxy) }
        .onChange(of: nav.settingsScrollTarget) { scrollToRequestedSection(proxy) }
      }
      .navigationTitle("Settings")
      .platformNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          saveButton
        }
      }
    }
    .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    .sheet(isPresented: $showPaywall) { PaywallSheet(feature: paywallFeature) }
    .sheet(isPresented: $showCamera) {
      #if os(iOS)
      CameraCaptureView { data in
        saveProfilePhotoData(data)
      }
      #elseif os(macOS)
      CameraCaptureView(
        onCapture: { data in
          saveProfilePhotoData(data)
          showCamera = false
        },
        onCancel: {
          showCamera = false
        }
      )
      .frame(minWidth: 560, minHeight: 420)
      #endif
    }
    .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
    .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.image]) { result in
      importProfilePhotoFile(result)
    }
    .confirmationDialog("Change profile photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
      Button("Choose from Photos") { presentPhotoPicker() }
      Button("Choose File") { presentFilePicker() }
      #if os(iOS)
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        Button("Take Photo") { presentCamera() }
      }
      #elseif os(macOS)
      Button("Take Photo") { presentCamera() }
      #endif
      Button("Cancel", role: .cancel) {}
    }
    .onAppear { reloadFromSettings() }
    .onChange(of: standardDoseText) { markUnsaved() }
    .onChange(of: deviceNameText) { markUnsaved() }
    .onChange(of: syncServerURLText) { markUnsaved() }
    .onChange(of: syncTokenText) { markUnsaved() }
    .onChange(of: syncEmailText) { markUnsaved() }
    .onChange(of: vanityNameText) { markUnsaved() }
    .onChange(of: homeCityText) { markUnsaved() }
    .onChange(of: homeCountryCode) { markUnsaved() }
    .onChange(of: homeAddressText) {
      markUnsaved()
      if suppressNextHomeLocationSearch {
        suppressNextHomeLocationSearch = false
      } else {
        scheduleHomeLocationSearch()
      }
    }
    .onChange(of: homeLatitudeText) { markUnsaved(); homeLocationError = nil }
    .onChange(of: homeLongitudeText) { markUnsaved(); homeLocationError = nil }
    .onChange(of: quickAmountTexts) { markUnsaved(); quickAmountsError = nil }
    .onChange(of: customIntervalText) { markUnsaved(); intervalError = nil }
    .onChange(of: photoPickerItem) { loadPhoto() }
    .onDisappear {
      homeLocationSearchTask?.cancel()
    }
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
              .platformKeyboardType(.decimalPad)
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
              rescheduleNotificationsIfNeeded()
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
              .platformKeyboardType(.numberPad)
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
        HStack(spacing: 8) {
          ForEach(0..<4, id: \.self) { index in
            TextField("Dose \(index + 1)", text: $quickAmountTexts[index])
              .platformKeyboardType(.decimalPad)
              .multilineTextAlignment(.center)
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(AppTheme.textPrimary)
              .padding(.vertical, 12)
              .padding(.horizontal, 8)
              .background(AppTheme.backgroundElevated)
              .clipShape(RoundedRectangle(cornerRadius: 9))
              .overlay(
                RoundedRectangle(cornerRadius: 9)
                  .stroke(quickAmountsError != nil ? AppTheme.statusRed : Color.clear, lineWidth: 1)
              )
          }
        }

        if let err = quickAmountsError {
          Text(err).font(.system(size: 12)).foregroundStyle(AppTheme.statusRed)
        } else {
          Text("Leave boxes empty to show fewer quick-dose buttons.")
            .font(.system(size: 12)).foregroundStyle(AppTheme.textMuted)
        }
      }
    }
  }

  private var displaySection: some View {
    settingsCard(title: "Display") {
      VStack(spacing: 0) {
        row(label: "Colour scheme") {
          @Bindable var s = settings
          Picker("Colour scheme", selection: $s.appearanceMode) {
            ForEach(AppAppearanceMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 230)
          .onChange(of: settings.appearanceMode) { markUnsaved() }
        }
        cardDivider
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

  private var colourSection: some View {
    settingsCard(title: "Colours") {
      VStack(alignment: .leading, spacing: 12) {
        if settings.proBetaAccepted {
          colourPickerRow("Accent", hex: customAccentBinding, resetHex: AppTheme.defaultAccentHex)
          cardDivider
          colourPickerRow("Main dose button", hex: customPrimaryButtonBinding, resetHex: AppTheme.defaultPrimaryButtonHex)
          cardDivider
          colourPickerRow("Quick dose buttons", hex: customQuickButtonBinding, resetHex: AppTheme.defaultQuickButtonHex)
          cardDivider
          colourPickerRow("Background", hex: customBackgroundBinding, resetHex: AppTheme.defaultBackgroundHex)
          Text("Uses the system colour picker, including crayons where available.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
        } else {
          HStack(alignment: .center, spacing: 10) {
            Image(systemName: "star.fill")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(AppTheme.proAmber)
            Text("Pro users can customise app colours, button colours, and background colour.")
              .font(.system(size: 13))
              .foregroundStyle(AppTheme.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Pro") {
              paywallFeature = .fullHistory
              showPaywall = true
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.proAmber)
          }
        }
      }
    }
  }

  private var notificationsSection: some View {
    settingsCard(title: "Notifications") {
      VStack(spacing: 10) {
        row(label: "Safe to redose reminder") {
          @Bindable var s = settings
          Toggle("Safe to redose reminder", isOn: $s.notificationsEnabled)
            .labelsHidden()
            .tint(AppTheme.accentBlue)
            .accessibilityLabel("Safe to redose reminder")
            .onChange(of: settings.notificationsEnabled) {
              markUnsaved()
              if settings.notificationsEnabled {
                Task {
                  await enableNotificationsFromSettings()
                }
              } else {
                NotificationManager.shared.cancelRedoseReminder()
                Task {
                  await refreshNotificationStatus()
                }
              }
            }
        }
        Text(notificationStatusMessage ?? "Notification status is being checked.")
          .font(.system(size: 12))
          .foregroundStyle(notificationStatusColour)
          .frame(maxWidth: .infinity, alignment: .leading)
        if settings.notificationsEnabled {
          Text("You'll receive a notification when your minimum interval has passed.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
          #if os(iOS)
          cardDivider
          row(label: "Lock Screen reminder") {
            @Bindable var s = settings
            Toggle("Lock Screen reminder", isOn: $s.lockScreenNotificationsEnabled)
              .labelsHidden()
              .tint(AppTheme.accentBlue)
              .accessibilityLabel("Lock Screen reminder")
              .onChange(of: settings.lockScreenNotificationsEnabled) {
                markUnsaved()
                if settings.lockScreenNotificationsEnabled {
                  Task {
                    let granted = await NotificationManager.shared.requestPermission(lockScreenDelivery: true)
                    if granted {
                      DoseStore.scheduleReminderForMostRecentDose(context: context, settings: settings)
                    } else {
                      settings.lockScreenNotificationsEnabled = false
                    }
                    await refreshNotificationStatus()
                  }
                } else {
                  rescheduleNotificationsIfNeeded()
                  Task {
                    await refreshNotificationStatus()
                  }
                }
              }
          }
          Text("Uses iPhone notification permissions for Lock Screen delivery. iOS settings and Focus can still hide it.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
          #endif
        }
      }
      .task {
        await refreshNotificationStatus()
      }
    }
  }

  private var notificationStatusColour: Color {
    guard let notificationStatusMessage else { return AppTheme.textMuted }
    return notificationStatusMessage.localizedCaseInsensitiveContains("blocked")
      ? AppTheme.statusAmber
      : AppTheme.textMuted
  }

  @MainActor
  private func enableNotificationsFromSettings() async {
    let granted = await NotificationManager.shared.requestPermission(
      lockScreenDelivery: settings.lockScreenNotificationsEnabled
    )
    if granted {
      DoseStore.scheduleReminderForMostRecentDose(context: context, settings: settings)
    } else {
      settings.notificationsEnabled = false
      settings.lockScreenNotificationsEnabled = false
    }
    await refreshNotificationStatus()
  }

  @MainActor
  private func refreshNotificationStatus() async {
    notificationStatusMessage = await NotificationManager.shared.authorizationStatusMessage()
  }

  private func rescheduleNotificationsIfNeeded() {
    DoseStore.scheduleReminderForMostRecentDose(context: context, settings: settings)
  }

  private var deviceSection: some View {
    settingsCard(title: "Device") {
      VStack(spacing: 0) {
        row(label: "Device name") {
          TextField("My iPhone", text: $deviceNameText)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: 180)
        }
        cardDivider
        HStack(spacing: 6) {
          Image(systemName: "lock.fill")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.statusGreen)
          Text(settings.syncEnabled ? "Dose data is stored locally and synced with your gTimer sync server." : "All dose data is stored locally on this device only.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
          Spacer()
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var syncSection: some View {
    settingsCard(title: "Device Sync") {
      VStack(alignment: .leading, spacing: 12) {
        syncAccessCard

        row(label: "Cross-device sync") {
          @Bindable var s = settings
          Toggle("Cross-device sync", isOn: $s.syncEnabled)
            .labelsHidden()
            .tint(AppTheme.accentBlue)
            .accessibilityLabel("Cross-device sync")
            .disabled(!canUseDeviceSync)
            .onChange(of: settings.syncEnabled) {
              if settings.syncEnabled && !settings.canUseDeviceSync {
                settings.syncEnabled = false
                syncAuthMessage = "Start the free sync trial or activate gTimer Pro to sync devices."
              }
              markUnsaved()
            }
        }

        VStack(alignment: .leading, spacing: 7) {
          Text("Server")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          TextField("https://sync.gtimer.app", text: $syncServerURLText)
            .platformPlainTextEntry()
            .font(.system(size: 14, design: .monospaced))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .disabled(!canUseDeviceSync)
        }

        VStack(alignment: .leading, spacing: 7) {
          Text("Advanced token")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          SecureField(settings.syncToken.isEmpty ? "Created after account login" : "Saved in keychain", text: $syncTokenText)
            .platformPlainTextEntry()
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .privacySensitive()
            .disabled(!canUseDeviceSync)
        }

        VStack(alignment: .leading, spacing: 7) {
          Text("Sync account")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          TextField("Email", text: $syncEmailText)
            .platformKeyboardType(.emailAddress)
            .platformPlainTextEntry()
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .disabled(!canUseDeviceSync)
          SecureField("Password", text: $syncPasswordText)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .privacySensitive()
            .disabled(!canUseDeviceSync)
          HStack(spacing: 8) {
            Button {
              authenticateSyncAccount(register: false)
            } label: {
              syncAuthButtonLabel("Sign in")
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticatingSync || !canUseDeviceSync)

            Button {
              authenticateSyncAccount(register: true)
            } label: {
              syncAuthButtonLabel("Create account")
            }
            .buttonStyle(.plain)
            .disabled(isAuthenticatingSync || !canUseDeviceSync)
          }
          if let syncAuthMessage {
            Text(syncAuthMessage)
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
          } else if !settings.syncAccountEmail.isEmpty {
            Text("Signed in as \(settings.syncAccountEmail).")
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
          }
        }

        if !syncDevices.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Devices")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
              Spacer()
              Button("Refresh") { loadSyncDevices() }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accentBlue)
            }
            ForEach(syncDevices) { device in
              syncDeviceRow(device)
            }
          }
        }

        HStack(spacing: 8) {
          Image(systemName: settings.syncEnabled ? "arrow.triangle.2.circlepath.circle.fill" : "icloud.slash.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(settings.syncEnabled ? AppTheme.accentBlue : AppTheme.textMuted)
          Text(settings.syncStatusMessage)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
            .lineLimit(2)
          Spacer()
          Button {
            performManualSync()
          } label: {
            HStack(spacing: 6) {
              if isSyncing {
                ProgressView()
                  .controlSize(.small)
              } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                  .font(.system(size: 12, weight: .semibold))
              }
              Text(isSyncing ? "Syncing" : "Sync now")
                .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accentBlue)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppTheme.accentBlue.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
          .disabled(isSyncing)
          .disabled(isSyncing || !canUseDeviceSync)
        }

        Text("Sync is optional. It uses the gTimer sync server, and each device gets its own token so lost devices can be removed.")
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.textMuted)
      }
    }
  }

  @ViewBuilder
  private var syncAccessCard: some View {
    let title = settings.proBetaAccepted
      ? "Included with gTimer Pro"
      : settings.isSyncTrialActive
        ? "Free sync trial active"
        : settings.syncTrialStartedAt == nil
          ? "Try device sync free"
          : "Sync trial ended"
    let detail = settings.proBetaAccepted
      ? "Sync can keep your dose history available across your signed-in devices."
      : settings.isSyncTrialActive
        ? "\(settings.syncTrialDaysRemaining) day\(settings.syncTrialDaysRemaining == 1 ? "" : "s") left. Activate gTimer Pro to keep device sync after the trial."
        : settings.syncTrialStartedAt == nil
          ? "Start a \(SettingsManager.syncTrialDurationDays)-day trial to try cross-device dose logging before choosing Pro."
          : "Activate gTimer Pro to keep syncing your dose history across devices."

    HStack(alignment: .center, spacing: 12) {
      Image(systemName: settings.canUseDeviceSync ? "icloud.fill" : "star.fill")
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(settings.canUseDeviceSync ? AppTheme.accentBlue : AppTheme.proAmber)
        .frame(width: 28, height: 28)
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(AppTheme.textPrimary)
        Text(detail)
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 8)
      if !settings.canUseDeviceSync {
        Button(settings.syncTrialStartedAt == nil ? "Start trial" : "gTimer Pro") {
          if settings.syncTrialStartedAt == nil {
            settings.startSyncTrialIfNeeded()
            syncAuthMessage = "Sync trial started. Create an account or sign in to begin syncing."
          } else {
            paywallFeature = .deviceSync
            showPaywall = true
          }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(settings.syncTrialStartedAt == nil ? AppTheme.accentBlue : AppTheme.proAmber)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .buttonStyle(.plain)
      }
    }
    .padding(12)
    .background((settings.canUseDeviceSync ? AppTheme.accentBlue : AppTheme.proAmber).opacity(0.10))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke((settings.canUseDeviceSync ? AppTheme.accentBlue : AppTheme.proAmber).opacity(0.22), lineWidth: 0.75)
    )
  }

  private func syncAuthButtonLabel(_ title: String) -> some View {
    HStack(spacing: 6) {
      if isAuthenticatingSync {
        ProgressView()
          .controlSize(.small)
      }
      Text(title)
        .font(.system(size: 13, weight: .semibold))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(AppTheme.accentBlue)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private func syncDeviceRow(_ device: SyncDevice) -> some View {
    HStack(spacing: 10) {
      Image(systemName: device.isRevoked ? "iphone.slash" : "desktopcomputer.and.macbook")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(device.isRevoked ? AppTheme.textMuted : AppTheme.accentBlue)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(device.name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textPrimary)
          if device.id == settings.syncDeviceID {
            Text("This device")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(AppTheme.statusGreen)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(AppTheme.statusGreen.opacity(0.12))
              .clipShape(Capsule())
          }
          if device.isRevoked {
            Text("Revoked")
              .font(.system(size: 10, weight: .bold))
              .foregroundStyle(AppTheme.textMuted)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(AppTheme.backgroundElevated)
              .clipShape(Capsule())
          }
        }
        Text("Last seen \(device.lastSeenAt ?? device.createdAt)")
          .font(.system(size: 11))
          .foregroundStyle(AppTheme.textMuted)
      }
      Spacer()
      if !device.isRevoked {
        Button("Remove") {
          revokeSyncDevice(device)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(device.id == settings.syncDeviceID ? AppTheme.statusAmber : AppTheme.statusRed)
        .buttonStyle(.plain)
      }
    }
    .padding(10)
    .background(AppTheme.backgroundElevated)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  private var locationSection: some View {
    settingsCard(title: "Dose Locations") {
      if settings.proBetaAccepted {
        VStack(spacing: 0) {
          row(label: "Attach location to new doses") {
            @Bindable var s = settings
            Toggle("Attach location to new doses", isOn: $s.attachLocationToDoses)
              .labelsHidden()
              .tint(AppTheme.accentBlue)
              .accessibilityLabel("Attach location to new doses")
              .onChange(of: settings.attachLocationToDoses) {
                markUnsaved()
                if settings.attachLocationToDoses {
                  LocationManager.shared.requestWhenInUsePermission()
                }
              }
          }
          if settings.attachLocationToDoses {
            // Permission-denied warning
            let status = LocationManager.shared.authorizationStatus
            if status == .denied || status == .restricted {
              cardDivider
              HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                  .font(.system(size: 12))
                  .foregroundStyle(AppTheme.statusAmber)
                VStack(alignment: .leading, spacing: 2) {
                  Text("Location access denied")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.statusAmber)
                  Text("Doses will still log normally. To record locations, enable permission in Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
              }
              .padding(.vertical, 6)
            }
            cardDivider
            row(label: "Show approximate location") {
              @Bindable var s = settings
              Toggle("Show approximate location", isOn: $s.locationApproximate)
                .labelsHidden()
                .tint(AppTheme.accentBlue)
                .accessibilityLabel("Show approximate location")
                .onChange(of: settings.locationApproximate) { markUnsaved() }
            }
            Text("This only rounds how saved locations are displayed in the app. iOS still provides precise coordinates when precise location permission is enabled.")
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
              .padding(.top, 2)
            cardDivider
            Button {
              openLocationSettings()
            } label: {
              HStack {
                Text("Manage location permission")
                  .font(.system(size: 15))
                  .foregroundStyle(AppTheme.accentBlue)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                  .font(.system(size: 13))
                  .foregroundStyle(AppTheme.accentBlue.opacity(0.6))
              }
              .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            cardDivider
            Text(settings.syncEnabled ? "Location data can sync with your account when device sync is on." : "Location data is stored locally on this device only while sync is off.")
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.textMuted)
              .padding(.vertical, 4)
          }
        }
      } else {
        Button {
          paywallFeature = .doseLocations
          showPaywall = true
        } label: {
          HStack(spacing: 10) {
            Image(systemName: "location.fill")
              .font(.system(size: 16))
              .foregroundStyle(AppTheme.accentBlue)
            VStack(alignment: .leading, spacing: 2) {
              Text("Track dose locations")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
              Text("See where you took each dose on a map.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textMuted)
            }
            Spacer()
            HStack(spacing: 4) {
              Image(systemName: "lock.fill").font(.system(size: 10))
              Text("Pro")
                .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(AppTheme.proAmber)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(AppTheme.proAmber.opacity(0.12))
            .clipShape(Capsule())
          }
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var homeLocationSection: some View {
    settingsCard(title: "Home Location") {
      VStack(alignment: .leading, spacing: 10) {
        row(label: "Country") {
          Picker("", selection: $homeCountryCode) {
            ForEach(EmergencyNumberCatalogue.countries) { country in
              Text(country.name).tag(country.code)
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .tint(AppTheme.accentBlue)
          .frame(maxWidth: 220)
        }
        cardDivider
        row(label: "City") {
          TextField("City", text: $homeCityText)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .frame(maxWidth: 180)
        }
        cardDivider
        VStack(alignment: .leading, spacing: 6) {
          Text("Address")
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
          TextField("Optional street address", text: $homeAddressText, axis: .vertical)
            .lineLimit(1...3)
            .font(.system(size: 15))
            .foregroundStyle(AppTheme.textPrimary)
            .padding(10)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .onChange(of: homeAddressText) {
              homeLocationError = nil
            }
          if !homeLocationSuggestions.isEmpty || !homeLocationResults.isEmpty {
            homeLocationSuggestionList
          }
          HStack(spacing: 8) {
            TextField("Latitude", text: $homeLatitudeText)
              .platformKeyboardType(.decimalPad)
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(AppTheme.textPrimary)
              .padding(10)
              .background(AppTheme.backgroundElevated)
              .clipShape(RoundedRectangle(cornerRadius: 9))
            TextField("Longitude", text: $homeLongitudeText)
              .platformKeyboardType(.decimalPad)
              .font(.system(size: 13, design: .monospaced))
              .foregroundStyle(AppTheme.textPrimary)
              .padding(10)
              .background(AppTheme.backgroundElevated)
              .clipShape(RoundedRectangle(cornerRadius: 9))
          }
          Button {
            lookUpHomeLocation()
          } label: {
            HStack(spacing: 8) {
              if isLookingUpHomeLocation {
                ProgressView()
                  .controlSize(.small)
              } else {
                Image(systemName: "magnifyingglass")
                  .font(.system(size: 12, weight: .semibold))
              }
              Text(isLookingUpHomeLocation ? "Looking up home address..." : "Look up home coordinates")
                .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accentBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.accentBlue.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
          }
          .buttonStyle(.plain)
          .disabled(isLookingUpHomeLocation || homeAddressText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)

          if let homeLocationError {
            Text(homeLocationError)
              .font(.system(size: 12))
              .foregroundStyle(AppTheme.statusAmber)
          }
        }
        cardDivider
        HStack(spacing: 8) {
          Image(systemName: "phone.fill")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusRed)
          Text("Emergency number: \(EmergencyNumberCatalogue.emergencyLabel(for: homeCountryCode).replacingOccurrences(of: "Call ", with: ""))")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.textSecondary)
          Spacer()
        }
        Text("This is used for Health & Safety emergency-number localisation. It can be just city and country; the address is optional.")
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.textMuted)
        #if os(macOS)
        Text("On Mac, this saved home address is also used as the dose location only when live location is unavailable.")
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.textMuted)
        #endif
      }
    }
  }

  private var homeLocationSuggestionList: some View {
    VStack(alignment: .leading, spacing: 8) {
      if !homeLocationSuggestions.isEmpty {
        Text("Saved")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.textMuted)
      }
      ForEach(homeLocationSuggestions) { location in
        Button {
          applyHomeLocation(location)
        } label: {
          locationSuggestionRow(location, icon: "clock.arrow.circlepath", actionLabel: "Fill")
        }
        .buttonStyle(.plain)
      }

      if !homeLocationResults.isEmpty {
        Text("Places")
          .font(.system(size: 11, weight: .bold))
          .foregroundStyle(AppTheme.textMuted)
          .padding(.top, homeLocationSuggestions.isEmpty ? 0 : 4)
      }
      ForEach(homeLocationResults) { location in
        Button {
          applyHomeLocation(location)
          ManualLocationStore.shared.save(
            name: location.name,
            latitude: location.latitude,
            longitude: location.longitude
          )
        } label: {
          locationSuggestionRow(location, icon: "mappin.and.ellipse", actionLabel: "Use")
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var profileSection: some View {
    settingsCard(title: "Profile (Pro)") {
      VStack(spacing: 14) {
        HStack(spacing: 14) {
          if let data = settings.profilePictureData {
            #if os(macOS)
            if let img = NSImage(data: data) {
              Image(nsImage: img)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52).clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.proAmber, lineWidth: 2))
            } else {
              profilePlaceholder
            }
            #else
            if let img = UIImage(data: data) {
              Image(uiImage: img)
                .resizable().scaledToFill()
                .frame(width: 52, height: 52).clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.proAmber, lineWidth: 2))
            } else {
              profilePlaceholder
            }
            #endif
          } else {
            profilePlaceholder
          }
          VStack(alignment: .leading, spacing: 4) {
            Button {
              showPhotoSourceDialog = true
            } label: {
              Text("Change Photo")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.proAmber)
            }
            .buttonStyle(.plain)
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
        if let err = photoImportError {
          Text(err)
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.statusAmber)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }

  // MARK: - Shared helpers

  private var cardDivider: some View {
    Divider().background(AppTheme.border).padding(.vertical, 4)
  }

  private var profilePlaceholder: some View {
    ZStack {
      Circle().fill(AppTheme.backgroundElevated).frame(width: 52, height: 52)
      Image(systemName: "person.fill").foregroundStyle(AppTheme.textMuted).font(.system(size: 22))
    }
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

  private func colourPickerRow(_ label: String, hex: Binding<String>, resetHex: String) -> some View {
    HStack(spacing: 10) {
      Text(label)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textPrimary)
      Spacer()
      Text(hex.wrappedValue)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(AppTheme.textMuted)
      ColorPicker(
        label,
        selection: Binding(
          get: { AppTheme.color(hex: hex.wrappedValue) },
          set: { newColor in
            hex.wrappedValue = AppTheme.hexString(from: newColor)
            markUnsaved()
          }
        )
      )
      .labelsHidden()
      Button {
        hex.wrappedValue = resetHex
        markUnsaved()
      } label: {
        Image(systemName: "arrow.counterclockwise")
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .foregroundStyle(AppTheme.textMuted)
      .accessibilityLabel("Reset \(label) colour")
    }
  }

  private var customAccentBinding: Binding<String> {
    Binding(
      get: { settings.customAccentHex },
      set: { settings.customAccentHex = $0 }
    )
  }

  private var customPrimaryButtonBinding: Binding<String> {
    Binding(
      get: { settings.customPrimaryButtonHex },
      set: { settings.customPrimaryButtonHex = $0 }
    )
  }

  private var customQuickButtonBinding: Binding<String> {
    Binding(
      get: { settings.customQuickButtonHex },
      set: { settings.customQuickButtonHex = $0 }
    )
  }

  private var customBackgroundBinding: Binding<String> {
    Binding(
      get: { settings.customBackgroundHex },
      set: { settings.customBackgroundHex = $0 }
    )
  }

  private func locationSuggestionRow(
    _ location: ManualDoseLocation,
    icon: String,
    actionLabel: String
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(AppTheme.accentBlue)
      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(AppTheme.textPrimary)
          .lineLimit(1)
        Text("\(coordinateText(location.latitude)), \(coordinateText(location.longitude))")
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(AppTheme.textMuted)
      }
      Spacer()
      Text(actionLabel)
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(AppTheme.accentBlue)
    }
    .padding(10)
    .background(AppTheme.backgroundElevated)
    .clipShape(RoundedRectangle(cornerRadius: 10))
  }

  // MARK: - Save / validate

  private func markUnsaved() {
    guard hasLoaded else { return }
    if saveState != .unsaved { saveState = .unsaved }
  }

  private func saveAll() {
    let enteredQuickAmounts = quickAmountTexts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    var parsed: [Double] = []
    for value in enteredQuickAmounts where !value.isEmpty {
      guard let amount = Double(value), amount > 0 else {
        quickAmountsError = "Each quick dose must be a positive number, or left blank."
        return
      }
      parsed.append(amount)
    }
    if parsed.count != Set(parsed.map { String(format: "%.6f", $0) }).count {
      quickAmountsError = "Quick doses must not contain duplicates."
      return
    }

    // Validate custom interval
    if !customIntervalText.isEmpty {
      guard let minutes = Int(customIntervalText), minutes >= 15 else {
        intervalError = "Minimum interval is 15 minutes."
        return
      }
      settings.safeIntervalMinutes = minutes
      rescheduleNotificationsIfNeeded()
    }

    if let d = Double(standardDoseText), d > 0 { settings.standardDose = d }
    settings.deviceName = deviceNameText
    settings.syncServerURL = syncServerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
    settings.syncToken = syncTokenText.trimmingCharacters(in: .whitespacesAndNewlines)
    settings.syncAccountEmail = syncEmailText.trimmingCharacters(in: .whitespacesAndNewlines)
    settings.vanityName = vanityNameText
    settings.homeCity = homeCityText.trimmingCharacters(in: .whitespacesAndNewlines)
    settings.homeCountryCode = homeCountryCode
    settings.homeAddress = homeAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanHomeLatitude = homeLatitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanHomeLongitude = homeLongitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleanHomeLatitude.isEmpty && cleanHomeLongitude.isEmpty {
      settings.homeLatitude = nil
      settings.homeLongitude = nil
    } else if
      let latitude = Double(cleanHomeLatitude),
      let longitude = Double(cleanHomeLongitude),
      (-90...90).contains(latitude),
      (-180...180).contains(longitude) {
      settings.homeLatitude = latitude
      settings.homeLongitude = longitude
      ManualLocationStore.shared.save(
        name: settings.homeAddress.isEmpty ? homeLocationLabel : settings.homeAddress,
        latitude: latitude,
        longitude: longitude
      )
    } else {
      homeLocationError = "Enter valid home latitude and longitude, or leave both blank."
      return
    }
    settings.quickAmounts = parsed

    quickAmountsError = nil
    intervalError = nil
    homeLocationError = nil
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
    syncServerURLText = settings.syncServerURL
    syncTokenText = settings.syncToken
    syncEmailText = settings.syncAccountEmail
    syncPasswordText = ""
    syncAuthMessage = nil
    vanityNameText = settings.vanityName
    homeCityText = settings.homeCity
    homeCountryCode = settings.homeCountryCode
    homeAddressText = settings.homeAddress
    homeLatitudeText = coordinateText(settings.homeLatitude)
    homeLongitudeText = coordinateText(settings.homeLongitude)
    ManualLocationStore.shared.absorbHistoryLocations(from: doseRecords)
    let amountStrings = settings.quickAmounts.prefix(4).map {
      $0.formatted(.number.precision(.fractionLength(1)))
    }
    quickAmountTexts = (0..<4).map { index in
      index < amountStrings.count ? amountStrings[index] : ""
    }
    customIntervalText = ""
    saveState = .idle
    quickAmountsError = nil
    intervalError = nil
    homeLocationError = nil
    if !settings.syncToken.isEmpty {
      loadSyncDevices()
    }
    Task { @MainActor in hasLoaded = true }
  }

  private func applyHomeLocation(_ location: ManualDoseLocation) {
    homeLocationSearchTask?.cancel()
    homeLocationResults = []
    suppressNextHomeLocationSearch = true
    homeAddressText = location.name
    homeLatitudeText = coordinateText(location.latitude)
    homeLongitudeText = coordinateText(location.longitude)
    homeLocationError = nil
    markUnsaved()
  }

  private func performManualSync() {
    guard settings.canUseDeviceSync else {
      settings.syncEnabled = false
      syncAuthMessage = "Start the free sync trial or activate gTimer Pro to sync devices."
      settings.syncStatusMessage = "Sync trial ended. Activate gTimer Pro to keep syncing."
      return
    }

    saveAll()
    guard quickAmountsError == nil,
          intervalError == nil,
          homeLocationError == nil else { return }

    isSyncing = true
    Task { @MainActor in
      await DoseSyncManager.shared.syncNow(context: context, settings: settings)
      isSyncing = false
    }
  }

  private func authenticateSyncAccount(register: Bool) {
    guard settings.canUseDeviceSync else {
      syncAuthMessage = "Start the free sync trial or activate gTimer Pro before signing in for device sync."
      return
    }

    saveAll()
    guard quickAmountsError == nil,
          intervalError == nil,
          homeLocationError == nil else { return }

    let email = syncEmailText.trimmingCharacters(in: .whitespacesAndNewlines)
    let password = syncPasswordText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard email.contains("@"), password.count >= 8 else {
      syncAuthMessage = "Enter an email and a password of at least 8 characters."
      return
    }

    isAuthenticatingSync = true
    syncAuthMessage = register ? "Creating account..." : "Signing in..."
    Task { @MainActor in
      defer {
        isAuthenticatingSync = false
        syncPasswordText = ""
      }
      do {
        let response: SyncAuthResponse
        if register {
          response = try await DoseSyncManager.shared.registerAccount(
            email: email,
            password: password,
            deviceName: deviceNameText,
            settings: settings
          )
        } else {
          response = try await DoseSyncManager.shared.login(
            email: email,
            password: password,
            deviceName: deviceNameText,
            settings: settings
          )
        }
        settings.syncToken = response.token
        settings.syncAccountEmail = response.user.email
        settings.syncDeviceID = response.device.id
        settings.syncEnabled = true
        syncTokenText = response.token
        syncEmailText = response.user.email
        syncAuthMessage = register ? "Account created. This device is signed in." : "Signed in. This device is registered."
        loadSyncDevices()
        await DoseSyncManager.shared.syncNow(context: context, settings: settings)
      } catch {
        syncAuthMessage = error.localizedDescription
      }
    }
  }

  private func loadSyncDevices() {
    guard settings.canUseDeviceSync, !settings.syncToken.isEmpty else {
      syncDevices = []
      return
    }
    Task { @MainActor in
      do {
        syncDevices = try await DoseSyncManager.shared.devices(settings: settings)
      } catch {
        syncAuthMessage = "Could not load devices: \(error.localizedDescription)"
      }
    }
  }

  private func revokeSyncDevice(_ device: SyncDevice) {
    Task { @MainActor in
      do {
        try await DoseSyncManager.shared.revokeDevice(device, settings: settings)
        if device.id == settings.syncDeviceID {
          settings.syncToken = ""
          settings.syncDeviceID = ""
          settings.syncEnabled = false
          syncTokenText = ""
          syncAuthMessage = "This device was removed and signed out."
        } else {
          syncAuthMessage = "\(device.name) was removed."
        }
        loadSyncDevices()
      } catch {
        syncAuthMessage = "Could not remove device: \(error.localizedDescription)"
      }
    }
  }

  private func lookUpHomeLocation() {
    let query = homeAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 3 else {
      homeLocationError = "Enter a home address or location name to look up."
      return
    }

    isLookingUpHomeLocation = true
    homeLocationError = nil
    Task { @MainActor in
      let results = await ManualLocationStore.shared.searchResults(
        matching: query,
        context: homeSearchContext,
        limit: 1
      )
      var location = results.first
      if location == nil {
        location = await ManualLocationStore.shared.lookUp(query)
      }
      guard let location else {
        isLookingUpHomeLocation = false
        homeLocationError = "Home address lookup could not find coordinates."
        return
      }

      applyHomeLocation(location)
      ManualLocationStore.shared.save(
        name: location.name,
        latitude: location.latitude,
        longitude: location.longitude
      )
      isLookingUpHomeLocation = false
    }
  }

  private func scheduleHomeLocationSearch() {
    homeLocationSearchTask?.cancel()
    let query = homeAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 3 else {
      homeLocationResults = []
      return
    }

    let context = homeSearchContext
    homeLocationSearchTask = Task {
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      let results = await ManualLocationStore.shared.searchResults(
        matching: query,
        context: context
      )
      guard !Task.isCancelled else { return }
      await MainActor.run {
        homeLocationResults = results.filter { result in
          !homeLocationSuggestions.contains(where: { saved in
            saved.name.caseInsensitiveCompare(result.name) == .orderedSame ||
              (abs(saved.latitude - result.latitude) < 0.0001 && abs(saved.longitude - result.longitude) < 0.0001)
          })
        }
      }
    }
  }

  private var homeSearchContext: ManualLocationSearchContext {
    ManualLocationSearchContext(
      homeCity: homeCityText,
      homeCountryCode: homeCountryCode,
      homeAddress: homeAddressText,
      homeCoordinate: parsedHomeCoordinate,
      currentCoordinate: LocationManager.shared.currentLocation?.coordinate
    )
  }

  private var parsedHomeCoordinate: CLLocationCoordinate2D? {
    guard let latitude = Double(homeLatitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
          let longitude = Double(homeLongitudeText.trimmingCharacters(in: .whitespacesAndNewlines)),
          (-90...90).contains(latitude),
          (-180...180).contains(longitude)
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private var homeLocationLabel: String {
    [
      homeAddressText,
      homeCityText,
      EmergencyNumberCatalogue.country(for: homeCountryCode)?.name ?? ""
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  private func coordinateText(_ value: Double?) -> String {
    guard let value else { return "" }
    return String(format: "%.6f", value)
  }

  private func loadPhoto() {
    guard let item = photoPickerItem else { return }
    Task {
      if let data = try? await item.loadTransferable(type: Data.self) {
        saveProfilePhotoData(data)
      } else {
        photoImportError = "That photo could not be loaded."
      }
      photoPickerItem = nil
    }
  }

  private func importProfilePhotoFile(_ result: Result<URL, Error>) {
    switch result {
    case .success(let url):
      let didStartAccessing = url.startAccessingSecurityScopedResource()
      defer {
        if didStartAccessing { url.stopAccessingSecurityScopedResource() }
      }
      do {
        saveProfilePhotoData(try Data(contentsOf: url))
      } catch {
        photoImportError = "That file could not be loaded."
      }
    case .failure:
      photoImportError = "No photo was selected."
    }
  }

  private func presentPhotoPicker() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      showPhotoPicker = true
    }
  }

  private func presentFilePicker() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      #if os(macOS)
      openProfilePhotoPanel()
      #else
      showFilePicker = true
      #endif
    }
  }

  private func presentCamera() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
      showCamera = true
    }
  }

  #if os(macOS)
  private func openProfilePhotoPanel() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.image]
    panel.prompt = "Choose"
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      importProfilePhotoFile(.success(url))
    }
  }
  #endif

  private func saveProfilePhotoData(_ data: Data) {
    guard canLoadProfileImage(from: data) else {
      photoImportError = "That image format could not be used."
      return
    }
    settings.profilePictureData = data
    photoImportError = nil
    markUnsaved()
  }

  private func canLoadProfileImage(from data: Data) -> Bool {
    #if os(macOS)
    NSImage(data: data) != nil
    #else
    UIImage(data: data) != nil
    #endif
  }

  private func scrollToRequestedSection(_ proxy: ScrollViewProxy) {
    guard nav.settingsScrollTarget == .quickAmounts else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      withAnimation(.snappy) {
        proxy.scrollTo(SettingsScrollTarget.quickAmounts, anchor: .top)
      }
      nav.settingsScrollTarget = nil
    }
  }

  private func openLocationSettings() {
    #if os(iOS)
    if let url = URL(string: UIApplication.openSettingsURLString) {
      openURL(url)
    }
    #elseif os(macOS)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
      openURL(url)
    }
    #endif
  }
}

#if os(iOS)
private struct CameraCaptureView: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  let onCapture: (Data) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.cameraCaptureMode = .photo
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(onCapture: onCapture, dismiss: dismiss)
  }

  final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    private let onCapture: (Data) -> Void
    private let dismiss: DismissAction

    init(onCapture: @escaping (Data) -> Void, dismiss: DismissAction) {
      self.onCapture = onCapture
      self.dismiss = dismiss
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage,
         let data = image.jpegData(compressionQuality: 0.86) {
        onCapture(data)
      }
      dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      dismiss()
    }
  }
}
#endif

#if os(macOS)
private struct CameraCaptureView: NSViewControllerRepresentable {
  let onCapture: (Data) -> Void
  let onCancel: () -> Void

  func makeNSViewController(context: Context) -> CameraCaptureViewController {
    CameraCaptureViewController(onCapture: onCapture, onCancel: onCancel)
  }

  func updateNSViewController(_ nsViewController: CameraCaptureViewController, context: Context) {}
}

private final class CameraCaptureViewController: NSViewController, AVCapturePhotoCaptureDelegate {
  private let onCapture: (Data) -> Void
  private let onCancel: () -> Void
  private let session = AVCaptureSession()
  private let output = AVCapturePhotoOutput()
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private let messageLabel = NSTextField(labelWithString: "Preparing camera...")
  private let captureButton = NSButton(title: "Take Photo", target: nil, action: nil)
  private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)

  init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
    self.onCapture = onCapture
    self.onCancel = onCancel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 420))
    view.wantsLayer = true
    view.layer?.backgroundColor = NSColor.black.cgColor

    messageLabel.font = .systemFont(ofSize: 15, weight: .medium)
    messageLabel.textColor = .white
    messageLabel.alignment = .center
    messageLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(messageLabel)

    captureButton.target = self
    captureButton.action = #selector(capturePhoto)
    captureButton.keyEquivalent = "\r"
    captureButton.translatesAutoresizingMaskIntoConstraints = false
    captureButton.isEnabled = false
    view.addSubview(captureButton)

    cancelButton.target = self
    cancelButton.action = #selector(cancel)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(cancelButton)

    NSLayoutConstraint.activate([
      messageLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      messageLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      messageLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      messageLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
      captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -54),
      captureButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
      cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 54),
      cancelButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
    ])
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    requestCameraAccess()
  }

  override func viewDidLayout() {
    super.viewDidLayout()
    previewLayer?.frame = view.bounds
  }

  override func viewWillDisappear() {
    super.viewWillDisappear()
    stopSession()
  }

  private func requestCameraAccess() {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      configureCamera()
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
        DispatchQueue.main.async {
          granted ? self?.configureCamera() : self?.showUnavailableMessage()
        }
      }
    default:
      showUnavailableMessage()
    }
  }

  private func configureCamera() {
    session.beginConfiguration()
    session.sessionPreset = .photo

    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device),
          session.canAddInput(input),
          session.canAddOutput(output) else {
      session.commitConfiguration()
      showUnavailableMessage()
      return
    }

    session.addInput(input)
    session.addOutput(output)
    session.commitConfiguration()

    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    preview.frame = view.bounds
    view.layer?.insertSublayer(preview, at: 0)
    previewLayer = preview
    messageLabel.isHidden = true
    captureButton.isEnabled = true

    DispatchQueue.global(qos: .userInitiated).async { [session] in
      session.startRunning()
    }
  }

  private func showUnavailableMessage() {
    messageLabel.stringValue = "Camera access is unavailable. Check macOS Privacy & Security settings."
    captureButton.isEnabled = false
  }

  @objc private func capturePhoto() {
    output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
  }

  @objc private func cancel() {
    onCancel()
  }

  func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    guard error == nil, let data = photo.fileDataRepresentation() else {
      showUnavailableMessage()
      return
    }
    stopSession()
    onCapture(data)
  }

  private func stopSession() {
    if session.isRunning {
      session.stopRunning()
    }
  }
}
#endif
