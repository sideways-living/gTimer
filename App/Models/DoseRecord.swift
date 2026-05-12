import Foundation
import SwiftData
import CoreLocation

@Model
final class DoseRecord {
  var id: UUID
  var amount: Double
  var unit: String
  var time: Date
  var deviceName: String
  var notes: String
  var missed: Bool
  var edited: Bool
  // Existing location fields
  var latitude: Double?
  var longitude: Double?
  var locationName: String?
  // New location metadata (nil on legacy records)
  var locationAccuracyMeters: Double?
  var locationCapturedAt: Date?
  // "automatic" | "manual" | "none" — nil means legacy record (treat as "none")
  var locationSource: String?

  init(
    id: UUID = UUID(),
    amount: Double,
    unit: String = "ml",
    time: Date = Date(),
    deviceName: String = "",
    notes: String = "",
    missed: Bool = false,
    edited: Bool = false,
    latitude: Double? = nil,
    longitude: Double? = nil,
    locationName: String? = nil,
    locationAccuracyMeters: Double? = nil,
    locationCapturedAt: Date? = nil,
    locationSource: String? = nil
  ) {
    self.id = id
    self.amount = amount
    self.unit = unit
    self.time = time
    self.deviceName = deviceName
    self.notes = notes
    self.missed = missed
    self.edited = edited
    self.latitude = latitude
    self.longitude = longitude
    self.locationName = locationName
    self.locationAccuracyMeters = locationAccuracyMeters
    self.locationCapturedAt = locationCapturedAt
    self.locationSource = locationSource
  }

  var hasLocation: Bool { latitude != nil && longitude != nil }

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude ?? 0, longitude: longitude ?? 0)
  }

  // Friendly label for display: place name, or rounded coords, or nil
  func displayLocation(approximate: Bool = false) -> String? {
    if let name = locationName, !name.isEmpty { return name }
    guard let lat = latitude, let lon = longitude else { return nil }
    if approximate {
      return String(format: "%.2f°, %.2f°", lat, lon)
    }
    return String(format: "%.4f°, %.4f°", lat, lon)
  }

  var resolvedLocationSource: String { locationSource ?? "none" }
}
