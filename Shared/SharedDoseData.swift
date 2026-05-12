import Foundation

struct SharedDoseData: Codable {
  var lastDoseTime: Date?
  var lastDoseAmount: Double?
  var lastDoseUnit: String?
  var safeIntervalMinutes: Int?
}
