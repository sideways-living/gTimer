import Foundation
import SwiftData

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
  var latitude: Double?
  var longitude: Double?
  var locationName: String?

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
    locationName: String? = nil
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
  }
}
