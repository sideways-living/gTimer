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

    if let location = await lookUpWithMapSearch(cleanQuery) {
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

  private func lookUpWithMapSearch(_ query: String) async -> ManualDoseLocation? {
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query

    do {
      let response = try await MKLocalSearch(request: request).start()
      guard let item = response.mapItems.first else { return nil }
      let coordinate = item.placemark.coordinate
      let name = bestName(for: item, fallback: query)
      return ManualDoseLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude)
    } catch {
      return nil
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
