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
  var tagsRaw: String?
  var peopleRaw: String?
  var missed: Bool
  var edited: Bool
  var earlyBySeconds: Double?
  // Existing location fields
  var latitude: Double?
  var longitude: Double?
  var locationName: String?
  // New location metadata (nil on legacy records)
  var locationAccuracyMeters: Double?
  var locationCapturedAt: Date?
  // "automatic" | "manual" | "none" — nil means legacy record (treat as "none")
  var locationSource: String?
  var createdAt: Date?
  var updatedAt: Date?
  var deletedAt: Date?
  var deletionReason: String?
  var lastSyncedAt: Date?

  init(
    id: UUID = UUID(),
    amount: Double,
    unit: String = "ml",
    time: Date = Date(),
    deviceName: String = "",
    notes: String = "",
    tags: [String] = [],
    people: [String] = [],
    missed: Bool = false,
    edited: Bool = false,
    earlyBySeconds: Double? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    locationName: String? = nil,
    locationAccuracyMeters: Double? = nil,
    locationCapturedAt: Date? = nil,
    locationSource: String? = nil,
    createdAt: Date? = nil,
    updatedAt: Date? = nil,
    deletedAt: Date? = nil,
    deletionReason: String? = nil,
    lastSyncedAt: Date? = nil
  ) {
    self.id = id
    self.amount = amount
    self.unit = unit
    self.time = time
    self.deviceName = deviceName
    self.notes = notes
    self.tagsRaw = DoseRecord.encodeList(tags)
    self.peopleRaw = DoseRecord.encodeList(people)
    self.missed = missed
    self.edited = edited
    self.earlyBySeconds = earlyBySeconds
    self.latitude = latitude
    self.longitude = longitude
    self.locationName = locationName
    self.locationAccuracyMeters = locationAccuracyMeters
    self.locationCapturedAt = locationCapturedAt
    self.locationSource = locationSource
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.deletedAt = deletedAt
    self.deletionReason = deletionReason
    self.lastSyncedAt = lastSyncedAt
  }

  var hasLocation: Bool { latitude != nil && longitude != nil }
  var isDeletedForSync: Bool { deletedAt != nil }

  var tags: [String] {
    get { DoseRecord.decodeList(tagsRaw) }
    set { tagsRaw = DoseRecord.encodeList(DoseRecord.normalizedTags(from: newValue)) }
  }

  var people: [String] {
    get { DoseRecord.decodeList(peopleRaw) }
    set { peopleRaw = DoseRecord.encodeList(DoseRecord.normalizedPeople(from: newValue)) }
  }

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

  var wasTakenEarly: Bool {
    guard let earlyBySeconds else { return false }
    return earlyBySeconds > 0
  }

  var formattedEarlyBy: String? {
    guard let earlyBySeconds, earlyBySeconds > 0 else { return nil }
    let totalMinutes = max(Int((earlyBySeconds / 60).rounded()), 1)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
    if hours > 0 { return "\(hours)h" }
    return "\(minutes)m"
  }

  func matchesHistorySearch(_ query: String) -> Bool {
    let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return true }
    let lower = cleaned.lowercased()
    if lower.hasPrefix("#") {
      let normalized = DoseRecord.normalizedTag(lower)
      return tags.contains { $0.lowercased() == normalized }
    }
    let searchable = [
      amount.formatted(.number.precision(.fractionLength(0...3))),
      unit,
      deviceName,
      notes,
      locationName ?? "",
      deletionReason ?? "",
      tags.joined(separator: " "),
      people.joined(separator: " ")
    ].joined(separator: " ").lowercased()
    return searchable.contains(lower)
  }

  static func normalizedTags(from input: String) -> [String] {
    let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
    return input
      .components(separatedBy: separators)
      .map(normalizedTag)
      .filter { !$0.isEmpty && $0 != "#" }
      .removingDuplicateStrings()
  }

  static func normalizedTags(from values: [String]) -> [String] {
    values.map(normalizedTag).filter { !$0.isEmpty && $0 != "#" }.removingDuplicateStrings()
  }

  static func normalizedPeople(from input: String) -> [String] {
    input
      .components(separatedBy: CharacterSet(charactersIn: ",\n"))
      .map(normalizedPerson)
      .filter { !$0.isEmpty }
      .removingDuplicateStrings()
  }

  static func normalizedPeople(from values: [String]) -> [String] {
    values.map(normalizedPerson).filter { !$0.isEmpty }.removingDuplicateStrings()
  }

  static func normalizedTag(_ raw: String) -> String {
    let cleaned = raw
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: ",.;:"))
      .lowercased()
    guard !cleaned.isEmpty else { return "" }
    return cleaned.hasPrefix("#") ? cleaned : "#\(cleaned)"
  }

  static func normalizedPerson(_ raw: String) -> String {
    raw
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
  }

  private static func encodeList(_ values: [String]) -> String? {
    let cleaned = values.filter { !$0.isEmpty }.removingDuplicateStrings()
    guard !cleaned.isEmpty else { return nil }
    guard let data = try? JSONEncoder().encode(cleaned) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private static func decodeList(_ raw: String?) -> [String] {
    guard let raw, let data = raw.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([String].self, from: data)) ?? []
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
