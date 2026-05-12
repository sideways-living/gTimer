import Foundation
import SwiftData
import WidgetKit

final class DoseStore {
  static func logDose(
    amount: Double,
    unit: String,
    time: Date = Date(),
    notes: String = "",
    missed: Bool = false,
    latitude: Double? = nil,
    longitude: Double? = nil,
    locationName: String? = nil,
    deviceName: String,
    context: ModelContext,
    settings: SettingsManager
  ) {
    let record = DoseRecord(
      amount: amount,
      unit: unit,
      time: time,
      deviceName: deviceName,
      notes: notes,
      missed: missed,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName
    )
    context.insert(record)
    try? context.save()
    updateShared(amount: amount, unit: unit, time: time, settings: settings)

    if settings.notificationsEnabled {
      NotificationManager.shared.scheduleRedoseReminder(
        after: time,
        intervalMinutes: settings.safeIntervalMinutes
      )
    }
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func delete(_ record: DoseRecord, context: ModelContext) {
    context.delete(record)
    try? context.save()
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func deleteAll(context: ModelContext) {
    let all = (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? []
    for r in all { context.delete(r) }
    try? context.save()
    updateShared(amount: nil, unit: nil, time: nil, settings: nil)
    WidgetCenter.shared.reloadAllTimelines()
  }

  private static func updateShared(amount: Double?, unit: String?, time: Date?, settings: SettingsManager?) {
    let data = SharedDoseData(
      lastDoseTime: time,
      lastDoseAmount: amount,
      lastDoseUnit: unit,
      safeIntervalMinutes: settings?.safeIntervalMinutes,
      countdownMode: settings?.countdownMode
    )
    if let encoded = try? JSONEncoder().encode(data) {
      AppGroup.sharedDefaults?.set(encoded, forKey: AppGroup.lastDoseKey)
    }
  }
}
