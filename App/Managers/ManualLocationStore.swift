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
  var currentCoordinate: CLLocationCoordinate2D?
}

final class ManualLocationStore {
  static let shared = ManualLocationStore()

  private let storageKey = "manualDoseLocations"
  private let maxSavedLocations = 25
  private let defaults: UserDefaults

  private init(defaults: UserDefaults = .standard) {
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

    if let location = await lookUpWithMapSearch(cleanQuery, region: nil, limit: 1).first {
      return location
    }
    return await lookUpWithGeocoder(cleanQuery)
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
        let coordinate = item.placemark.coordinate
        let name = bestName(for: item, fallback: query)
        return ManualDoseLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
      }
    } catch {
      return []
    }
  }

  private func lookUpWithGeocoder(_ query: String) async -> ManualDoseLocation? {
    await withCheckedContinuation { continuation in
      CLGeocoder().geocodeAddressString(query) { placemarks, _ in
        guard let place = placemarks?.first,
              let location = place.location
        else {
          continuation.resume(returning: nil)
          return
        }

        let components = [
          place.name,
          place.locality,
          place.administrativeArea,
          place.country
        ]
          .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
        let name = components.removingDuplicates().joined(separator: ", ")
        continuation.resume(returning: ManualDoseLocation(
          name: name.isEmpty ? query : name,
          latitude: location.coordinate.latitude,
          longitude: location.coordinate.longitude
        ))
      }
    }
  }

  private func bestName(for item: MKMapItem, fallback: String) -> String {
    let place = item.placemark
    let components = [
      item.name,
      place.title,
      place.locality,
      place.administrativeArea,
      place.country
    ]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let name = components.removingDuplicates().joined(separator: ", ")
    return name.isEmpty ? fallback : name
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

    let country = EmergencyNumberCatalogue.country(for: context.homeCountryCode)?.name ?? ""
    let address = [
      context.homeAddress,
      context.homeCity,
      country
    ]
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .joined(separator: ", ")
    if !address.isEmpty, let home = await lookUpWithGeocoder(address) {
      return CLLocationCoordinate2D(latitude: home.latitude, longitude: home.longitude)
    }

    return context.currentCoordinate
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

private extension Array where Element == String {
  func removingDuplicates() -> [String] {
    var seen: [String] = []
    for value in self where !seen.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
      seen.append(value)
    }
    return seen
  }
}
