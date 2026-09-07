import SwiftUI
import CoreLocation

private enum MissedDoseLocationChoice: String, CaseIterable, Identifiable {
  case none = "None"
  case current = "Current"
  case home = "Home"
  case manual = "Search"

  var id: String { rawValue }
}

struct MissedDoseSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  @State private var amountText = "1.5"
  @State private var selectedDate = Date()
  @State private var notes = ""
  @State private var locationChoice: MissedDoseLocationChoice = .none
  @State private var locationNameText = ""
  @State private var latitudeText = ""
  @State private var longitudeText = ""
  @State private var locationError: String?
  @State private var isResolvingLocation = false
  @State private var isLookingUpLocation = false
  @State private var placeSearchResults: [ManualDoseLocation] = []
  @State private var placeSearchTask: Task<Void, Never>?
  @State private var suppressNextPlaceSearch = false
  @State private var isLogging = false

  private var locationAvailable: Bool {
    settings.attachLocationToDoses &&
      LocationManager.shared.hasLocationPermission
  }

  private var savedLocationSuggestions: [ManualDoseLocation] {
    ManualLocationStore.shared.suggestions(matching: locationNameText, limit: 4)
  }

  private var hasHomeLocation: Bool {
    homeCoordinate != nil || !homeLocationLabel.isEmpty
  }

  var body: some View {
    NavigationStack {
      ZStack {
        AppTheme.backgroundPrimary.ignoresSafeArea()
        ScrollView {
          VStack(spacing: 20) {
            sheetHeader(title: "Missed Dose")
            infoBox
            amountField
            dateField
            notesField
            locationSection
            logButton
          }
          .padding(20)
        }
      }
      .navigationTitle("Missed Dose")
      .platformInlineNavigationTitle()
    }
    .presentationDetents([.large])
    .preferredColorScheme(.dark)
    .onAppear {
      amountText = settings.standardDose.formatted(.number.precision(.fractionLength(1)))
    }
    .onDisappear {
      placeSearchTask?.cancel()
    }
  }

  private var amountField: some View {
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
  }

  private var dateField: some View {
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
  }

  private var notesField: some View {
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
  }

  private var locationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Location")
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)

      Picker("Location", selection: $locationChoice) {
        ForEach(MissedDoseLocationChoice.allCases) { choice in
          Text(choice.rawValue).tag(choice)
        }
      }
      .pickerStyle(.segmented)
      .onChange(of: locationChoice) {
        locationError = nil
      }

      locationChoiceDescription

      if locationChoice == .manual {
        manualLocationEditor
      }

      if let locationError {
        Text(locationError)
          .font(.system(size: 12))
          .foregroundStyle(AppTheme.statusAmber)
      }
    }
    .padding(14)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
  }

  private var locationChoiceDescription: some View {
    Group {
      switch locationChoice {
      case .none:
        Text("The missed dose will be logged without a location.")
      case .current:
        Text(locationAvailable ? "Logs your current position, not where you were then." : "gTimer will request location access if needed, then try to capture your current position.")
      case .home:
        Text(hasHomeLocation ? "Uses your saved home location from Settings." : "Add a home address or coordinates in Settings before using this option.")
      case .manual:
        Text("Type a place or address, select a saved result, or look up coordinates.")
      }
    }
    .font(.system(size: 12))
    .foregroundStyle(AppTheme.textMuted)
    .fixedSize(horizontal: false, vertical: true)
  }

  private var manualLocationEditor: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField("Location name or address", text: $locationNameText)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textPrimary)
        .padding(12)
        .background(AppTheme.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: locationNameText) {
          locationError = nil
          if suppressNextPlaceSearch {
            suppressNextPlaceSearch = false
            return
          }
          schedulePlaceSearch()
        }

      if !savedLocationSuggestions.isEmpty || !placeSearchResults.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          if !savedLocationSuggestions.isEmpty {
            Text("Saved")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(AppTheme.textMuted)
          }
          ForEach(savedLocationSuggestions) { suggestion in
            Button {
              applyManualLocation(suggestion)
            } label: {
              locationSuggestionRow(suggestion, icon: "clock.arrow.circlepath", actionLabel: "Fill")
            }
            .buttonStyle(.plain)
          }

          if !placeSearchResults.isEmpty {
            Text("Places")
              .font(.system(size: 11, weight: .bold))
              .foregroundStyle(AppTheme.textMuted)
              .padding(.top, savedLocationSuggestions.isEmpty ? 0 : 4)
          }
          ForEach(placeSearchResults) { result in
            Button {
              applyManualLocation(result)
              ManualLocationStore.shared.save(
                name: result.name,
                latitude: result.latitude,
                longitude: result.longitude
              )
            } label: {
              locationSuggestionRow(result, icon: "mappin.and.ellipse", actionLabel: "Use")
            }
            .buttonStyle(.plain)
          }
        }
      }

      HStack(spacing: 10) {
        coordinateField("Latitude", text: $latitudeText)
        coordinateField("Longitude", text: $longitudeText)
      }

      HStack(spacing: 10) {
        locationActionButton(
          icon: "magnifyingglass",
          label: isLookingUpLocation ? "Looking up..." : "Look up",
          isBusy: isLookingUpLocation
        ) {
          lookUpManualLocation()
        }
        .disabled(isLookingUpLocation || locationNameText.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)

        locationActionButton(
          icon: "location.fill",
          label: isResolvingLocation ? "Getting..." : "Use current",
          isBusy: isResolvingLocation
        ) {
          captureManualCurrentLocation()
        }
        .disabled(isResolvingLocation)
      }
    }
  }

  private var logButton: some View {
    Button {
      logMissedDose()
    } label: {
      Text(isLogging ? "Logging..." : "Log Missed Dose")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(AppTheme.proAmber)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .disabled(isLogging)
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

  private func sheetHeader(title: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 20, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
      Spacer()
      Button {
        dismiss()
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
        .background(AppTheme.backgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
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

  private func locationActionButton(
    icon: String,
    label: String,
    isBusy: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        if isBusy {
          ProgressView()
            .controlSize(.small)
        } else {
          Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
        }
        Text(label)
          .font(.system(size: 13, weight: .semibold))
      }
      .foregroundStyle(AppTheme.accentBlue)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(AppTheme.accentBlue.opacity(0.10))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }

  private func logMissedDose() {
    guard !isLogging else { return }
    isLogging = true
    locationError = nil

    Task { @MainActor in
      guard let resolvedLocation = await resolveSelectedLocation() else {
        isLogging = false
        return
      }

      let amount = Double(amountText) ?? settings.standardDose
      DoseStore.logDose(
        amount: amount,
        unit: settings.unit,
        time: selectedDate,
        notes: notes,
        missed: true,
        capturedLocation: resolvedLocation.location,
        locationName: resolvedLocation.name,
        locationSource: resolvedLocation.source,
        deviceName: settings.deviceName,
        context: context,
        settings: settings
      )
      dismiss()
    }
  }

  private func resolveSelectedLocation() async -> (location: CLLocation?, name: String?, source: String)? {
    switch locationChoice {
    case .none:
      return (nil, nil, "none")
    case .current:
      return await currentLocationForDose()
    case .home:
      return await homeLocationForDose()
    case .manual:
      return await manualLocationForDose()
    }
  }

  private func currentLocationForDose() async -> (location: CLLocation?, name: String?, source: String)? {
    let locationManager = LocationManager.shared
    locationManager.requestWhenInUsePermission()
    let captured = await locationManager.captureForDose()
    guard let captured else {
      locationError = "Current location was not available."
      return nil
    }
    return (captured, locationManager.locationName, "current")
  }

  private func homeLocationForDose() async -> (location: CLLocation?, name: String?, source: String)? {
    guard let home = await homeFallbackLocation() else {
      locationError = "Home location is not available. Add a home address or coordinates in Settings, or choose another location option."
      return nil
    }
    return (home.location, home.name, "home-fallback")
  }

  private func manualLocationForDose() async -> (location: CLLocation?, name: String?, source: String)? {
    let cleanName = locationNameText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanLatitude = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanLongitude = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)

    if let coordinate = manualCoordinate {
      if !cleanName.isEmpty {
        ManualLocationStore.shared.save(
          name: cleanName,
          latitude: coordinate.latitude,
          longitude: coordinate.longitude
        )
      }
      return (
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
        cleanName.isEmpty ? nil : cleanName,
        "manual"
      )
    }

    if cleanLatitude.isEmpty && cleanLongitude.isEmpty && cleanName.count >= 3 {
      isLookingUpLocation = true
      let found = await ManualLocationStore.shared.searchResults(
        matching: cleanName,
        context: searchContext,
        limit: 1
      ).first ?? ManualLocationStore.shared.suggestions(matching: cleanName, limit: 1).first
      isLookingUpLocation = false

      if let found {
        applyManualLocation(found)
        ManualLocationStore.shared.save(name: found.name, latitude: found.latitude, longitude: found.longitude)
        return (
          CLLocation(latitude: found.latitude, longitude: found.longitude),
          found.name,
          "manual"
        )
      }
    }

    locationError = "Select a saved place, look up coordinates, use current location, or enter valid latitude and longitude."
    return nil
  }

  private func homeFallbackLocation() async -> (location: CLLocation, name: String)? {
    let context = ManualLocationSearchContext(
      homeCity: settings.homeCity,
      homeCountryCode: settings.homeCountryCode,
      homeAddress: settings.homeAddress,
      homeCoordinate: homeCoordinate,
      currentCoordinate: LocationManager.shared.currentLocation?.coordinate
    )
    guard let fallback = await ManualLocationStore.shared.homeFallbackLocation(context: context) else { return nil }
    ManualLocationStore.shared.save(
      name: fallback.name,
      latitude: fallback.latitude,
      longitude: fallback.longitude
    )
    return (
      CLLocation(latitude: fallback.latitude, longitude: fallback.longitude),
      fallback.name
    )
  }

  private func applyManualLocation(_ location: ManualDoseLocation) {
    placeSearchTask?.cancel()
    placeSearchResults = []
    suppressNextPlaceSearch = true
    locationNameText = location.name
    latitudeText = coordinateText(location.latitude)
    longitudeText = coordinateText(location.longitude)
    locationError = nil
  }

  private func captureManualCurrentLocation() {
    isResolvingLocation = true
    locationError = nil
    let locationManager = LocationManager.shared
    locationManager.requestWhenInUsePermission()

    Task { @MainActor in
      let captured = await locationManager.captureForDose()
      guard let captured else {
        isResolvingLocation = false
        locationError = "Current location was not available."
        return
      }

      locationNameText = locationManager.locationName ?? "Current location"
      latitudeText = coordinateText(captured.coordinate.latitude)
      longitudeText = coordinateText(captured.coordinate.longitude)
      ManualLocationStore.shared.save(
        name: locationNameText,
        latitude: captured.coordinate.latitude,
        longitude: captured.coordinate.longitude
      )
      isResolvingLocation = false
    }
  }

  private func lookUpManualLocation() {
    let query = locationNameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 3 else {
      locationError = "Enter a location name or address to look up."
      return
    }

    isLookingUpLocation = true
    locationError = nil
    Task { @MainActor in
      let location = await ManualLocationStore.shared.searchResults(
        matching: query,
        context: searchContext,
        limit: 1
      ).first

      guard let location else {
        isLookingUpLocation = false
        locationError = "Location lookup could not find coordinates."
        return
      }

      applyManualLocation(location)
      ManualLocationStore.shared.save(name: location.name, latitude: location.latitude, longitude: location.longitude)
      isLookingUpLocation = false
    }
  }

  private func schedulePlaceSearch() {
    placeSearchTask?.cancel()
    let query = locationNameText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 3 else {
      placeSearchResults = []
      return
    }

    let context = searchContext
    placeSearchTask = Task {
      try? await Task.sleep(for: .milliseconds(350))
      guard !Task.isCancelled else { return }
      let results = await ManualLocationStore.shared.searchResults(
        matching: query,
        context: context
      )
      guard !Task.isCancelled else { return }
      await MainActor.run {
        placeSearchResults = results.filter { result in
          !savedLocationSuggestions.contains(where: { saved in
            saved.name.caseInsensitiveCompare(result.name) == .orderedSame ||
              (abs(saved.latitude - result.latitude) < 0.0001 && abs(saved.longitude - result.longitude) < 0.0001)
          })
        }
      }
    }
  }

  private var searchContext: ManualLocationSearchContext {
    ManualLocationSearchContext(
      homeCity: settings.homeCity,
      homeCountryCode: settings.homeCountryCode,
      homeAddress: settings.homeAddress,
      homeCoordinate: homeCoordinate,
      currentCoordinate: LocationManager.shared.currentLocation?.coordinate
    )
  }

  private var manualCoordinate: CLLocationCoordinate2D? {
    let cleanLatitude = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleanLongitude = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      let latitude = Double(cleanLatitude),
      let longitude = Double(cleanLongitude),
      (-90...90).contains(latitude),
      (-180...180).contains(longitude)
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func coordinateText(_ value: Double?) -> String {
    guard let value else { return "" }
    return String(format: "%.6f", value)
  }

  private func coordinateText(_ value: Double) -> String {
    String(format: "%.6f", value)
  }

  private var homeLocationLabel: String {
    let country = EmergencyNumberCatalogue.country(for: settings.homeCountryCode)?.name ?? ""
    return [
      settings.homeAddress,
      settings.homeCity,
      country
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  private var homeCoordinate: CLLocationCoordinate2D? {
    guard let latitude = settings.homeLatitude,
          let longitude = settings.homeLongitude,
          (-90...90).contains(latitude),
          (-180...180).contains(longitude)
    else { return nil }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}
