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
    refreshSharedAfterDeletion(context: context)
    WidgetCenter.shared.reloadAllTimelines()
  }

  static func deleteAll(context: ModelContext) {
    let all = (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? []
    for r in all { context.delete(r) }
    try? context.save()
    updateShared(amount: nil, unit: nil, time: nil, settings: nil)
    WidgetCenter.shared.reloadAllTimelines()
  }

  // After a single deletion, find the new most-recent dose and update shared
  // defaults, preserving the interval/countdownMode already stored there.
  private static func refreshSharedAfterDeletion(context: ModelContext) {
    let desc = FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .reverse)]
    )
    let remaining = (try? context.fetch(desc)) ?? []
    var interval: Int? = nil
    var countdownMode: Bool? = nil
    if let raw = AppGroup.sharedDefaults?.data(forKey: AppGroup.lastDoseKey),
       let existing = try? JSONDecoder().decode(SharedDoseData.self, from: raw) {
      interval = existing.safeIntervalMinutes
      countdownMode = existing.countdownMode
    }
    let newest = remaining.first
    let data = SharedDoseData(
      lastDoseTime: newest?.time,
      lastDoseAmount: newest?.amount,
      lastDoseUnit: newest?.unit,
      safeIntervalMinutes: interval,
      countdownMode: countdownMode
    )
    if let encoded = try? JSONEncoder().encode(data) {
      AppGroup.sharedDefaults?.set(encoded, forKey: AppGroup.lastDoseKey)
    }
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
