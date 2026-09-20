import Foundation
import MapKit

struct ManualDoseLocation: Codable, Identifiable, Equatable {
  var id: UUID
  var name: String
  var latitude: Double
  var longitude: Double

  init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
  }
}

struct ManualLocationSearchContext {
  var homeCity: String
  var homeCountryCode: String
  var homeAddress: String
  var homeCoordinate: CLLocationCoordinate2D?
  var currentCoordinate: CLLocationCoordinate2D?
}

final class ManualLocationStore {
  static let shared = ManualLocationStore()

  private let storageKey = "manualDoseLocations"
  private let maxSavedLocations = 25
  private let defaults: UserDefaults

  private init(defaults: UserDefaults = AppPreferences.defaults) {
    self.defaults = defaults
  }

  func suggestions(matching query: String, limit: Int = 3) -> [ManualDoseLocation] {
    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanQuery.isEmpty else { return [] }

    return savedLocations()
      .filter { $0.name.localizedCaseInsensitiveContains(cleanQuery) }
      .prefix(limit)
      .map { $0 }
  }

  func absorbHistoryLocations(from records: [DoseRecord]) {
    for record in records where record.hasLocation {
      guard let latitude = record.latitude, let longitude = record.longitude else { continue }
      let name = record.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
      let fallbackName = String(format: "%.6f, %.6f", latitude, longitude)
      save(
        name: name?.isEmpty == false ? name ?? fallbackName : fallbackName,
        latitude: latitude,
        longitude: longitude
      )
    }
  }

  func searchResults(
    matching query: String,
    context: ManualLocationSearchContext,
    limit: Int = 4
  ) async -> [ManualDoseLocation] {
    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard cleanQuery.count >= 3 else { return [] }

    let biasCoordinate = await searchBiasCoordinate(context: context)
    var results: [ManualDoseLocation] = []
    let region = biasCoordinate.map {
      MKCoordinateRegion(
        center: $0,
        latitudinalMeters: 35_000,
        longitudinalMeters: 35_000
      )
    }

    for searchQuery in searchQueries(for: cleanQuery, context: context) {
      let found = await lookUpWithMapSearch(searchQuery, region: region, limit: limit)
      results.append(contentsOf: found)
      if results.count >= limit { break }
    }

    return ranked(
      deduplicated(results),
      query: cleanQuery,
      biasCoordinate: biasCoordinate
    )
    .prefix(limit)
    .map { $0 }
  }

  func save(name: String, latitude: Double, longitude: Double) {
    let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanName.isEmpty else { return }
    guard (-90...90).contains(latitude), (-180...180).contains(longitude) else { return }

    var locations = savedLocations()
    locations.removeAll {
      $0.name.caseInsensitiveCompare(cleanName) == .orderedSame ||
        (abs($0.latitude - latitude) < 0.000001 && abs($0.longitude - longitude) < 0.000001)
    }
    locations.insert(ManualDoseLocation(name: cleanName, latitude: latitude, longitude: longitude), at: 0)
    if locations.count > maxSavedLocations {
      locations = Array(locations.prefix(maxSavedLocations))
    }
    persist(locations)
  }

  func lookUp(_ query: String) async -> ManualDoseLocation? {
    let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanQuery.isEmpty else { return nil }

    return await lookUpWithMapSearch(cleanQuery, region: nil, limit: 1).first
  }

  func homeFallbackLocation(context: ManualLocationSearchContext) async -> ManualDoseLocation? {
    let name = homeLocationName(context: context)

    if let coordinate = context.homeCoordinate {
      return ManualDoseLocation(
        name: name,
        latitude: coordinate.latitude,
        longitude: coordinate.longitude
      )
    }

    guard !name.isEmpty else { return nil }
    return await lookUpWithMapSearch(name, region: nil, limit: 1).first
  }

  func nearestKnownLocation(
    to currentLocation: CLLocation,
    home: ManualDoseLocation?,
    historyRecords: [DoseRecord],
    maximumDistanceMeters: CLLocationDistance = 150
  ) -> ManualDoseLocation? {
    if let home,
       distance(from: currentLocation, to: home) <= maximumDistanceMeters {
      return home
    }

    let historyLocations = historyRecords.compactMap { record -> ManualDoseLocation? in
      guard record.deletedAt == nil,
            let latitude = record.latitude,
            let longitude = record.longitude,
            let name = record.locationName?.trimmingCharacters(in: .whitespacesAndNewlines),
            !name.isEmpty
      else { return nil }
      return ManualDoseLocation(name: name, latitude: latitude, longitude: longitude)
    }
    let candidates = deduplicated(savedLocations() + historyLocations)
      .filter { distance(from: currentLocation, to: $0) <= maximumDistanceMeters }

    return candidates.min { first, second in
      let firstUses = historyUseCount(for: first.name, in: historyLocations)
      let secondUses = historyUseCount(for: second.name, in: historyLocations)
      if firstUses != secondUses { return firstUses > secondUses }
      return distance(from: currentLocation, to: first) < distance(from: currentLocation, to: second)
    }
  }

  private func savedLocations() -> [ManualDoseLocation] {
    guard let data = defaults.data(forKey: storageKey),
          let decoded = try? JSONDecoder().decode([ManualDoseLocation].self, from: data)
    else { return [] }
    return decoded
  }

  private func persist(_ locations: [ManualDoseLocation]) {
    guard let data = try? JSONEncoder().encode(locations) else { return }
    defaults.set(data, forKey: storageKey)
  }

  private func distance(from current: CLLocation, to location: ManualDoseLocation) -> CLLocationDistance {
    current.distance(from: CLLocation(latitude: location.latitude, longitude: location.longitude))
  }

  private func historyUseCount(for name: String, in locations: [ManualDoseLocation]) -> Int {
    locations.reduce(into: 0) { count, location in
      if location.name.caseInsensitiveCompare(name) == .orderedSame {
        count += 1
      }
    }
  }

  private func lookUpWithMapSearch(
    _ query: String,
    region: MKCoordinateRegion?,
    limit: Int
  ) async -> [ManualDoseLocation] {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    if let region {
      request.region = region
      request.resultTypes = [.address, .pointOfInterest]
    }

    do {
      let response = try await MKLocalSearch(request: request).start()
      return response.mapItems.prefix(limit).map { item in
        let coordinate = MapItemLocationFormatter.coordinate(for: item)
        let name = MapItemLocationFormatter.displayName(for: item, fallback: query)
        return ManualDoseLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
      }
    } catch {
      return []
    }
  }

  private func searchQueries(for query: String, context: ManualLocationSearchContext) -> [String] {
    let city = context.homeCity.trimmingCharacters(in: .whitespacesAndNewlines)
    let address = context.homeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    let country = EmergencyNumberCatalogue.country(for: context.homeCountryCode)?.name ?? ""

    var queries: [String] = []
    if !address.isEmpty {
      queries.append([query, address, city, country].filter { !$0.isEmpty }.joined(separator: ", "))
    }
    if !city.isEmpty {
      queries.append([query, city, country].filter { !$0.isEmpty }.joined(separator: ", "))
    }
    queries.append(query)
    return queries.removingDuplicates()
  }

  private func searchBiasCoordinate(context: ManualLocationSearchContext) async -> CLLocationCoordinate2D? {
    if let saved = savedLocations().first {
      return CLLocationCoordinate2D(latitude: saved.latitude, longitude: saved.longitude)
    }

    if let homeCoordinate = context.homeCoordinate {
      return homeCoordinate
    }

    let country = EmergencyNumberCatalogue.country(for: context.homeCountryCode)?.name ?? ""
    let address = [
      context.homeAddress,
      context.homeCity,
      country
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
    if !address.isEmpty, let home = await lookUpWithMapSearch(address, region: nil, limit: 1).first {
      return CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
    }

    return context.currentCoordinate
  }

  private func homeLocationName(context: ManualLocationSearchContext) -> String {
    let country = EmergencyNumberCatalogue.country(for: context.homeCountryCode)?.name ?? ""
    return [
      context.homeAddress,
      context.homeCity,
      country
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
  }

  private func deduplicated(_ locations: [ManualDoseLocation]) -> [ManualDoseLocation] {
    var unique: [ManualDoseLocation] = []
    for location in locations {
      let exists = unique.contains {
        $0.name.caseInsensitiveCompare(location.name) == .orderedSame ||
          (abs($0.latitude - location.latitude) < 0.0001 && abs($0.longitude - location.longitude) < 0.0001)
      }
      if !exists { unique.append(location) }
    }
    return unique
  }

  private func ranked(
    _ locations: [ManualDoseLocation],
    query: String,
    biasCoordinate: CLLocationCoordinate2D?
  ) -> [ManualDoseLocation] {
    locations.sorted { first, second in
      score(first, query: query, biasCoordinate: biasCoordinate) >
        score(second, query: query, biasCoordinate: biasCoordinate)
    }
  }

  private func score(
    _ location: ManualDoseLocation,
    query: String,
    biasCoordinate: CLLocationCoordinate2D?
  ) -> Double {
    var score = 0.0
    if location.name.localizedCaseInsensitiveContains(query) { score += 40 }
    if location.name.localizedCaseInsensitiveContains(query.components(separatedBy: " ").first ?? query) { score += 10 }

    if let biasCoordinate {
      let bias = CLLocation(latitude: biasCoordinate.latitude, longitude: biasCoordinate.longitude)
      let candidate = CLLocation(latitude: location.latitude, longitude: location.longitude)
      let distanceKm = bias.distance(from: candidate) / 1000
      score += max(0, 50 - min(distanceKm, 50))
    }

    return score
  }
}

enum MapItemLocationFormatter {
  static func coordinate(for item: MKMapItem) -> CLLocationCoordinate2D {
    item.placemark.coordinate
  }

  static func displayName(for item: MKMapItem, fallback: String) -> String {
    let components = components(itemName: item.name, placemark: item.placemark)
    let name = components.joined(separator: ", ")
    return name.isEmpty ? fallback : name
  }

  static func reverseGeocodeSummary(for location: CLLocation) async -> (name: String?, countryCode: String?) {
    if #available(iOS 26.0, macOS 26.0, *) {
      guard let request = MKReverseGeocodingRequest(location: location),
            let item = try? await request.mapItems.first
      else { return (nil, nil) }

      let placemark = item.placemark
      return (
        displayName(for: item, fallback: coordinateLabel(placemark.coordinate)),
        countryCode(for: placemark)
      )
    }

    guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
      return (nil, nil)
    }
    return (
      components(itemName: nil, placemark: placemark).joined(separator: ", "),
      countryCode(for: placemark)
    )
  }

  static func reverseGeocodeName(for coordinate: CLLocationCoordinate2D) async -> String? {
    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let result = await reverseGeocodeSummary(for: location)
    return cleaned(result.name)
  }

  static func components(itemName: String?, placemark: CLPlacemark) -> [String] {
    [
      itemName,
      placemark.name,
      streetAddress(for: placemark),
      localityAddress(for: placemark),
      placemark.country
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .removingDuplicates()
  }

  static func countryCode(for placemark: CLPlacemark) -> String? {
    if let iso = placemark.isoCountryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
       !iso.isEmpty {
      return iso.uppercased()
    }

    guard let country = placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines),
          !country.isEmpty
    else { return nil }
    return EmergencyNumberCatalogue.countries.first {
      $0.name.caseInsensitiveCompare(country) == .orderedSame
    }?.code
  }

  private static func streetAddress(for placemark: CLPlacemark) -> String? {
    let address = [
      placemark.subThoroughfare,
      placemark.thoroughfare
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return cleaned(address)
  }

  private static func localityAddress(for placemark: CLPlacemark) -> String? {
    let address = [
      placemark.subLocality,
      placemark.locality,
      placemark.administrativeArea
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .removingDuplicates()
      .joined(separator: ", ")
    return cleaned(address)
  }

  private static func coordinateLabel(_ coordinate: CLLocationCoordinate2D) -> String {
    String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
  }

  private static func cleaned(_ string: String?) -> String? {
    let value = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return value.isEmpty ? nil : value
  }
}

private extension Array where Element == String {
  func removingDuplicates() -> [String] {
    var seen: [String] = []
    for value in self where !seen.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
      seen.append(value)
    }
    return seen
  }
}
