import Foundation
import SwiftData
import CoreLocation
import WidgetKit

final class DoseStore {
  static func logDose(
    amount: Double,
    unit: String,
    time: Date = Date(),
    notes: String = "",
    missed: Bool = false,
    earlyBySeconds: Double? = nil,
    capturedLocation: CLLocation? = nil,
    locationName: String? = nil,
    locationSource: String = "none",
    deviceName: String,
    context: ModelContext,
    settings: SettingsManager
  ) {
    let lat = capturedLocation?.coordinate.latitude
    let lon = capturedLocation?.coordinate.longitude
    let accuracy = capturedLocation?.horizontalAccuracy
    let capturedAt = capturedLocation != nil ? Date() : nil

    let record = DoseRecord(
      amount: amount,
      unit: unit,
      time: time,
      deviceName: deviceName,
      notes: notes,
      missed: missed,
      earlyBySeconds: earlyBySeconds,
      latitude: lat,
      longitude: lon,
      locationName: locationName,
      locationAccuracyMeters: accuracy,
      locationCapturedAt: capturedAt,
      locationSource: capturedLocation != nil ? locationSource : "none"
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

  // After an in-place edit, re-derive the most-recent dose and update shared
  // defaults so the widget reflects the corrected data.
  static func refreshSharedAfterEdit(context: ModelContext, settings: SettingsManager) {
    let desc = FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .reverse)]
    )
    if let newest = (try? context.fetch(desc))?.first {
      updateShared(amount: newest.amount, unit: newest.unit,
                   time: newest.time, settings: settings)
    }
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
