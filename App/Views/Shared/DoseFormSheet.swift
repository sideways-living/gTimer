import SwiftUI
import MapKit
import CoreLocation

enum DoseFormKind {
  case add
  case edit
  case missed
}

struct DoseFormLocationSelection {
  var name: String
  var coordinate: CLLocationCoordinate2D?
  var source: String
  var accuracyMeters: Double?
  var capturedAt: Date?

  var isEmpty: Bool {
    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && coordinate == nil
  }

  var clLocation: CLLocation? {
    guard let coordinate else { return nil }
    return CLLocation(
      coordinate: coordinate,
      altitude: 0,
      horizontalAccuracy: accuracyMeters ?? -1,
      verticalAccuracy: -1,
      timestamp: capturedAt ?? Date()
    )
  }
}

struct DoseFormResult {
  var amount: Double
  var time: Date
  var notes: String
  var location: DoseFormLocationSelection
}

struct DoseFormSheet: View {
  @Environment(SettingsManager.self) private var settings
  @Environment(\.dismiss) private var dismiss

  var kind: DoseFormKind
  var title: String
  var submitTitle: String
  var initialAmount: Double
  var initialTime: Date
  var initialNotes: String
  var initialLocationName: String?
  var initialLatitude: Double?
  var initialLongitude: Double?
  var onSubmit: (DoseFormResult) -> Void

  @State private var amountText = ""
  @State private var selectedTime = Date()
  @State private var notes = ""
  @State private var locationText = ""
  @State private var selectedCoordinate: CLLocationCoordinate2D?
  @State private var selectedLocationSource = "manual"
  @State private var selectedAccuracy: Double?
  @State private var selectedCapturedAt: Date?
  @State private var locationError: String?
  @State private var isCapturingLocation = false
  @State private var isResolvingMapPin = false
  @State private var placeSearchResults: [ManualDoseLocation] = []
  @State private var placeSearchTask: Task<Void, Never>?
  @State private var suppressNextPlaceSearch = false
  @State private var mapPosition: MapCameraPosition = .automatic

  private var parsedAmount: Double? {
    guard let amount = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)),
          amount > 0 else { return nil }
    return amount
  }

  private var savedLocationSuggestions: [ManualDoseLocation] {
    ManualLocationStore.shared.suggestions(matching: locationText, limit: 3)
  }

  private var allLocationSuggestions: [ManualDoseLocation] {
    (savedLocationSuggestions + placeSearchResults).removingDuplicateLocations()
  }

  var body: some View {
    GeometryReader { geometry in
      let twoColumns = geometry.size.width >= 760
      VStack(alignment: .leading, spacing: 18) {
        header

        if twoColumns {
          HStack(alignment: .top, spacing: 18) {
            formColumn
              .frame(width: min(geometry.size.width * 0.48, 560))
            mapColumn
              .frame(maxWidth: .infinity, minHeight: 440)
          }
        } else {
          ScrollView {
            VStack(alignment: .leading, spacing: 16) {
              formColumn
              mapColumn
                .frame(height: 320)
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(AppTheme.backgroundPrimary.ignoresSafeArea())
    }
    #if os(macOS)
    .frame(minWidth: 900, idealWidth: 1040, maxWidth: .infinity, minHeight: 620, idealHeight: 700, maxHeight: .infinity)
    #endif
    .presentationDetents([.large])
    .presentationBackground(AppTheme.backgroundPrimary)
    .preferredColorScheme(.dark)
    .onAppear(perform: loadInitialValues)
    .onDisappear { placeSearchTask?.cancel() }
    .onChange(of: locationText) {
      if suppressNextPlaceSearch {
        suppressNextPlaceSearch = false
      } else {
        selectedLocationSource = "manual"
        selectedAccuracy = nil
        selectedCapturedAt = nil
        if locationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          selectedCoordinate = nil
        }
        refreshPlaceSearch()
      }
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Text(title)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(AppTheme.textPrimary)
      Spacer()
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(AppTheme.textSecondary)
          .frame(width: 34, height: 34)
          .background(AppTheme.backgroundCard)
          .clipShape(Circle())
      }
      .buttonStyle(.plain)
      .help("Close")
      .accessibilityLabel("Close")
    }
  }

  private var formColumn: some View {
    VStack(alignment: .leading, spacing: 14) {
      compactEntryRow
      suggestionsList

      VStack(alignment: .leading, spacing: 8) {
        Text("Notes")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(AppTheme.textSecondary)
        TextField("Optional note", text: $notes, axis: .vertical)
          .font(.system(size: 15))
          .foregroundStyle(AppTheme.textPrimary)
          .lineLimit(3...6)
          .padding(12)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
      }

      if let locationError {
        Text(locationError)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(AppTheme.statusAmber)
      }

      Spacer(minLength: 0)

      Button {
        submit()
      } label: {
        Text(submitTitle)
          .font(.system(size: 17, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 15)
          .background(parsedAmount == nil ? AppTheme.backgroundElevated : AppTheme.accentBlue)
          .clipShape(RoundedRectangle(cornerRadius: 14))
      }
      .buttonStyle(.plain)
      .disabled(parsedAmount == nil)
    }
  }

  private var compactEntryRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Dose details")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppTheme.textSecondary)

      HStack(spacing: 8) {
        TextField("Amount", text: $amountText)
          .platformKeyboardType(.decimalPad)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(AppTheme.textPrimary)
          .frame(width: 88)
          .padding(10)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
          .accessibilityLabel("Dose amount")

        DatePicker("", selection: $selectedTime, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
          .labelsHidden()
          .colorScheme(.dark)
          .padding(7)
          .background(AppTheme.backgroundCard)
          .clipShape(RoundedRectangle(cornerRadius: 10))
          .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
          .accessibilityLabel("Dose date and time")

        locationInput
      }
    }
  }

  private var locationInput: some View {
    HStack(spacing: 6) {
      TextField("Address, suburb, venue or hotel", text: $locationText)
        .font(.system(size: 15))
        .foregroundStyle(AppTheme.textPrimary)
        .textFieldStyle(.plain)

      Button {
        useCurrentLocation()
      } label: {
        Image(systemName: "location.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(AppTheme.accentBlue)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .help("Use current location")
      .accessibilityLabel("Use current location")
      .disabled(isCapturingLocation)

      Button {
        useHomeLocation()
      } label: {
        Image(systemName: "house.fill")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(AppTheme.textSecondary)
          .frame(width: 28, height: 28)
      }
      .buttonStyle(.plain)
      .help("Use saved home location")
      .accessibilityLabel("Use saved home location")
    }
    .padding(.leading, 11)
    .padding(.trailing, 5)
    .padding(.vertical, 7)
    .background(AppTheme.backgroundCard)
    .clipShape(RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border))
  }

  @ViewBuilder
  private var suggestionsList: some View {
    let suggestions = allLocationSuggestions
    if !suggestions.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
        ForEach(suggestions.prefix(5)) { location in
          Button {
            apply(location: location, source: "manual")
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "mappin.circle.fill")
                .foregroundStyle(AppTheme.accentBlue)
              Text(location.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
              Spacer()
            }
            .padding(9)
            .background(AppTheme.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: 9))
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var mapColumn: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Map")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(AppTheme.textSecondary)
        Spacer()
        if isResolvingMapPin {
          ProgressView()
            .controlSize(.small)
        }
      }

      MapReader { proxy in
        Map(position: $mapPosition) {
          if let selectedCoordinate {
            Marker(locationText.isEmpty ? "Dose location" : locationText, coordinate: selectedCoordinate)
          }
        }
        .mapControls {
          MapCompass()
          MapScaleView()
          MapUserLocationButton()
        }
        .onTapGesture(coordinateSpace: .local) { point in
          if let coordinate = proxy.convert(point, from: .local) {
            applyMapPin(coordinate)
          }
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border))
    }
  }

  private func loadInitialValues() {
    amountText = initialAmount.formatted(.number.precision(.fractionLength(1)))
    selectedTime = initialTime
    notes = initialNotes
    locationText = initialLocationName ?? ""

    if let latitude = initialLatitude, let longitude = initialLongitude {
      let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
      selectedCoordinate = coordinate
      selectedLocationSource = "manual"
      focusMap(on: coordinate, meters: 900)
    } else if let home = homeCoordinate {
      focusMap(on: home, meters: 4_000)
    } else if let current = LocationManager.shared.currentLocation?.coordinate {
      focusMap(on: current, meters: 2_000)
    }

    refreshPlaceSearch()
  }

  private func submit() {
    guard let amount = parsedAmount else { return }
    let cleanLocation = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    if let selectedCoordinate, !cleanLocation.isEmpty {
      ManualLocationStore.shared.save(
        name: cleanLocation,
        latitude: selectedCoordinate.latitude,
        longitude: selectedCoordinate.longitude
      )
    }
    onSubmit(
      DoseFormResult(
        amount: amount,
        time: selectedTime,
        notes: notes,
        location: DoseFormLocationSelection(
          name: cleanLocation,
          coordinate: selectedCoordinate,
          source: selectedLocationSource,
          accuracyMeters: selectedAccuracy,
          capturedAt: selectedCapturedAt
        )
      )
    )
    dismiss()
  }

  private func refreshPlaceSearch() {
    let query = locationText.trimmingCharacters(in: .whitespacesAndNewlines)
    locationError = nil
    placeSearchTask?.cancel()
    guard query.count >= 3 else {
      placeSearchResults = []
      return
    }

    let context = searchContext
    placeSearchTask = Task { @MainActor in
      let results = await ManualLocationStore.shared.searchResults(matching: query, context: context, limit: 5)
      guard !Task.isCancelled else { return }
      placeSearchResults = results
    }
  }

  private func apply(location: ManualDoseLocation, source: String) {
    suppressNextPlaceSearch = true
    locationText = location.name
    let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    selectedCoordinate = coordinate
    selectedLocationSource = source
    selectedAccuracy = nil
    selectedCapturedAt = nil
    placeSearchResults = []
    locationError = nil
    focusMap(on: coordinate, meters: 900)
  }

  private func useCurrentLocation() {
    isCapturingLocation = true
    locationError = nil
    LocationManager.shared.requestWhenInUsePermission()
    Task { @MainActor in
      let captured = await LocationManager.shared.captureForDose()
      isCapturingLocation = false
      guard let captured else {
        locationError = "Current location is not available yet."
        return
      }

      let fallbackName = LocationManager.shared.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let name = fallbackName.isEmpty ? coordinateLabel(captured.coordinate) : fallbackName
      apply(
        location: ManualDoseLocation(
          name: name,
          latitude: captured.coordinate.latitude,
          longitude: captured.coordinate.longitude
        ),
        source: "current"
      )
      selectedAccuracy = captured.horizontalAccuracy >= 0 ? captured.horizontalAccuracy : nil
      selectedCapturedAt = captured.timestamp
    }
  }

  private func useHomeLocation() {
    Task { @MainActor in
      if let home = await ManualLocationStore.shared.homeFallbackLocation(context: searchContext) {
        apply(location: home, source: "home-fallback")
      } else {
        locationError = "Add a home location in Settings first."
      }
    }
  }

  private func applyMapPin(_ coordinate: CLLocationCoordinate2D) {
    selectedCoordinate = coordinate
    selectedLocationSource = "manual"
    selectedAccuracy = nil
    selectedCapturedAt = nil
    focusMap(on: coordinate, meters: 900)

    Task { @MainActor in
      isResolvingMapPin = true
      let name = await reverseGeocode(coordinate) ?? coordinateLabel(coordinate)
      isResolvingMapPin = false
      suppressNextPlaceSearch = true
      locationText = name
      locationError = nil
    }
  }

  private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
    guard let request = MKReverseGeocodingRequest(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)) else {
      return nil
    }
    do {
      let mapItems = try await request.mapItems
      guard let item = mapItems.first else { return nil }
      let components = reverseGeocodeComponents(for: item)
      return components.isEmpty ? nil : components.joined(separator: ", ")
    } catch {
      return nil
    }
  }

  private func reverseGeocodeComponents(for item: MKMapItem) -> [String] {
    [
      item.name,
      item.address?.shortAddress,
      item.addressRepresentations?.cityWithContext(.full),
      item.address?.fullAddress
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .removingDuplicateStrings()
  }

  private func focusMap(on coordinate: CLLocationCoordinate2D, meters: CLLocationDistance) {
    mapPosition = .region(
      MKCoordinateRegion(
        center: coordinate,
        latitudinalMeters: meters,
        longitudinalMeters: meters
      )
    )
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

  private var homeCoordinate: CLLocationCoordinate2D? {
    guard let latitude = settings.homeLatitude,
          let longitude = settings.homeLongitude,
          (-90...90).contains(latitude),
          (-180...180).contains(longitude) else {
      return nil
    }
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  private func coordinateLabel(_ coordinate: CLLocationCoordinate2D) -> String {
    String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
  }
}

private extension Array where Element == ManualDoseLocation {
  func removingDuplicateLocations() -> [ManualDoseLocation] {
    var seen = Set<String>()
    return filter { location in
      let key = "\(location.name.lowercased())|\(String(format: "%.5f", location.latitude))|\(String(format: "%.5f", location.longitude))"
      if seen.contains(key) { return false }
      seen.insert(key)
      return true
    }
  }
}

private extension Array where Element == String {
  func removingDuplicateStrings() -> [String] {
    var seen = Set<String>()
    return filter { value in
      let key = value.lowercased()
      if seen.contains(key) { return false }
      seen.insert(key)
      return true
    }
  }
}
