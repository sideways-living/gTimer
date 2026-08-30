import SwiftUI
import PhotosUI
import WidgetKit
import CoreLocation
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
  @State private var saveState: SaveState = .idle
  @State private var customIntervalText = ""
  @State private var standardDoseText = ""
  @State private var deviceNameText = ""
  @State private var vanityNameText = ""
  @State private var photoPickerItem: PhotosPickerItem?
  @State private var showPhotoSourceDialog = false
  @State private var showPhotoPicker = false
  @State private var showFilePicker = false
  @State private var showCamera = false
  @State private var photoImportError: String? = nil
  @State private var quickAmountTexts = Array(repeating: "", count: 4)
  @State private var quickAmountsError: String? = nil
  @State private var intervalError: String? = nil
  @State private var hasLoaded = false
  @State private var showPaywall = false
  @State private var paywallFeature: ProFeature = .doseLocations

  private let intervalPresets = [60, 90, 120]
  private var hasChanges: Bool { saveState == .unsaved }

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
            notificationsSection
            deviceSection
            locationSection
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
      Button("Choose from Photos") { showPhotoPicker = true }
      Button("Choose File") { showFilePicker = true }
      #if os(iOS)
      if UIImagePickerController.isSourceTypeAvailable(.camera) {
        Button("Take Photo") { showCamera = true }
      }
      #elseif os(macOS)
      Button("Take Photo") { showCamera = true }
      #endif
      Button("Cancel", role: .cancel) {}
    }
    .onAppear { reloadFromSettings() }
    .onChange(of: standardDoseText) { markUnsaved() }
    .onChange(of: deviceNameText) { markUnsaved() }
    .onChange(of: vanityNameText) { markUnsaved() }
    .onChange(of: quickAmountTexts) { markUnsaved(); quickAmountsError = nil }
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
          Toggle("Safe to redose reminder", isOn: $s.notificationsEnabled)
            .labelsHidden()
            .tint(AppTheme.accentBlue)
            .accessibilityLabel("Safe to redose reminder")
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
          Text("All dose data is stored locally on this device only.")
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textMuted)
          Spacer()
        }
        .padding(.vertical, 6)
      }
    }
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
            Text("Location data is stored locally on this device only. It is never shared or uploaded.")
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
    Task { @MainActor in hasLoaded = true }
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
