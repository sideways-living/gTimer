import Foundation
import SwiftData
import CoreLocation
import WidgetKit

@MainActor
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
    let rawAccuracy = capturedLocation?.horizontalAccuracy
    let accuracy = rawAccuracy.flatMap { $0 >= 0 ? $0 : nil }
    let capturedAt = capturedLocation != nil ? Date() : nil
    let cleanLocationName = locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasNamedLocation = cleanLocationName?.isEmpty == false

    let changeTime = Date()
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
      locationName: hasNamedLocation ? cleanLocationName : nil,
      locationAccuracyMeters: accuracy,
      locationCapturedAt: capturedAt,
      locationSource: capturedLocation != nil || hasNamedLocation ? locationSource : "none",
      createdAt: changeTime,
      updatedAt: changeTime
    )
    context.insert(record)
    try? context.save()
    updateShared(amount: amount, unit: unit, time: time, settings: settings)

    if settings.notificationsEnabled {
      NotificationManager.shared.scheduleRedoseReminder(
        after: time,
        intervalMinutes: settings.safeIntervalMinutes,
        lockScreenDelivery: settings.lockScreenNotificationsEnabled
      )
    }
    WidgetCenter.shared.reloadAllTimelines()
    DoseSyncManager.shared.syncAfterLocalChange(context: context, settings: settings)
  }

  static func delete(_ record: DoseRecord, context: ModelContext, settings: SettingsManager? = nil) {
    if settings?.syncEnabled == true {
      markDeletedForSync(record)
    } else {
      context.delete(record)
    }
    try? context.save()
    refreshSharedAfterDeletion(context: context)
    WidgetCenter.shared.reloadAllTimelines()
    if let settings {
      DoseSyncManager.shared.syncAfterLocalChange(context: context, settings: settings)
    }
  }

  static func deleteAll(context: ModelContext, settings: SettingsManager? = nil) {
    let all = (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? []
    for r in all {
      if settings?.syncEnabled == true {
        markDeletedForSync(r)
      } else {
        context.delete(r)
      }
    }
    try? context.save()
    updateShared(amount: nil, unit: nil, time: nil, settings: nil)
    WidgetCenter.shared.reloadAllTimelines()
    if let settings {
      DoseSyncManager.shared.syncAfterLocalChange(context: context, settings: settings)
    }
  }

  // After an in-place edit, re-derive the most-recent dose and update shared
  // defaults so the widget reflects the corrected data.
  static func refreshSharedAfterEdit(
    context: ModelContext,
    settings: SettingsManager,
    scheduleSync: Bool = true
  ) {
    backfillMissingEarlyDoseTiming(context: context, settings: settings)

    let desc = FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .reverse)]
    )
    if let newest = (try? context.fetch(desc))?.first {
      updateShared(amount: newest.amount, unit: newest.unit,
                   time: newest.time, settings: settings)
    }
    WidgetCenter.shared.reloadAllTimelines()
    if scheduleSync {
      DoseSyncManager.shared.syncAfterLocalChange(context: context, settings: settings)
    }
  }

  static func backfillMissingEarlyDoseTiming(context: ModelContext, settings: SettingsManager) {
    let asc = FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .forward)]
    )
    let records = ((try? context.fetch(asc)) ?? []).filter { !$0.isDeletedForSync }
    guard records.count > 1 else { return }

    let intervalSeconds = Double(settings.safeIntervalMinutes) * 60
    var previous: DoseRecord?
    var changed = false

    for record in records {
      defer { previous = record }
      guard record.earlyBySeconds == nil, let previous else { continue }
      let elapsed = record.time.timeIntervalSince(previous.time)
      guard elapsed >= 0, elapsed < intervalSeconds else { continue }
      record.earlyBySeconds = intervalSeconds - elapsed
      record.updatedAt = Date()
      changed = true
    }

    if changed {
      try? context.save()
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  // After a single deletion, find the new most-recent dose and update shared
  // defaults, preserving the interval/countdownMode already stored there.
  private static func refreshSharedAfterDeletion(context: ModelContext) {
    let desc = FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .reverse)]
    )
    let remaining = ((try? context.fetch(desc)) ?? []).filter { !$0.isDeletedForSync }
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

  static func markChangedForSync(_ record: DoseRecord) {
    if record.createdAt == nil { record.createdAt = record.time }
    record.updatedAt = Date()
  }

  private static func markDeletedForSync(_ record: DoseRecord) {
    let now = Date()
    if record.createdAt == nil { record.createdAt = record.time }
    record.updatedAt = now
    record.deletedAt = now
  }
}

@MainActor
final class DoseSyncManager {
  static let shared = DoseSyncManager()

  private var isSyncing = false
  private let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
  private let fallbackDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  func syncAfterLocalChange(context: ModelContext, settings: SettingsManager) {
    guard settings.syncEnabled else { return }
    Task { @MainActor in
      await syncNow(context: context, settings: settings)
    }
  }

  func syncNow(context: ModelContext, settings: SettingsManager) async {
    guard !isSyncing else { return }
    guard settings.syncEnabled else {
      settings.syncStatusMessage = "Sync is off."
      return
    }
    guard !settings.syncToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      settings.syncStatusMessage = "Add your sync token first."
      return
    }
    guard let baseURL = URL(string: settings.syncServerURL.trimmingCharacters(in: .whitespacesAndNewlines)),
          baseURL.scheme?.hasPrefix("http") == true else {
      settings.syncStatusMessage = "Enter a valid sync server URL."
      return
    }

    isSyncing = true
    settings.syncStatusMessage = "Syncing..."
    defer { isSyncing = false }

    do {
      let localRecords = try context.fetch(FetchDescriptor<DoseRecord>())
      let dirtyRecords = localRecords.filter { record in
        let updatedAt = effectiveUpdatedAt(for: record)
        guard let lastSyncedAt = record.lastSyncedAt else { return true }
        return updatedAt > lastSyncedAt
      }

      if !dirtyRecords.isEmpty {
        try await push(records: dirtyRecords, to: baseURL, settings: settings)
        let syncedAt = Date()
        for record in dirtyRecords {
          record.lastSyncedAt = syncedAt
        }
        try context.save()
      }

      var hasMore = true
      while hasMore {
        let response = try await pull(from: baseURL, settings: settings)
        merge(response.changes.doses, context: context)
        settings.syncCursor = response.cursor
        hasMore = response.hasMore
        try context.save()
      }

      DoseStore.refreshSharedAfterEdit(context: context, settings: settings, scheduleSync: false)
      settings.lastSyncAt = Date()
      settings.syncStatusMessage = "Last synced \(settings.lastSyncAt?.formatted(date: .omitted, time: .shortened) ?? "now")."
    } catch {
      settings.syncStatusMessage = "Sync failed: \(error.localizedDescription)"
    }
  }

  func registerAccount(
    email: String,
    password: String,
    deviceName: String,
    settings: SettingsManager
  ) async throws -> SyncAuthResponse {
    try await authenticate(
      path: "v1/auth/register",
      email: email,
      password: password,
      deviceName: deviceName,
      settings: settings
    )
  }

  func login(
    email: String,
    password: String,
    deviceName: String,
    settings: SettingsManager
  ) async throws -> SyncAuthResponse {
    try await authenticate(
      path: "v1/auth/login",
      email: email,
      password: password,
      deviceName: deviceName,
      settings: settings
    )
  }

  func devices(settings: SettingsManager) async throws -> [SyncDevice] {
    let baseURL = try syncBaseURL(settings)
    var request = URLRequest(url: baseURL.appending(path: "v1/auth/devices"))
    request.addValue("Bearer \(settings.syncToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    try validateHTTPResponse(response, data: data)
    return try JSONDecoder().decode(SyncDevicesResponse.self, from: data).devices
  }

  func revokeDevice(_ device: SyncDevice, settings: SettingsManager) async throws {
    let baseURL = try syncBaseURL(settings)
    var request = URLRequest(url: baseURL.appending(path: "v1/auth/devices/\(device.id)"))
    request.httpMethod = "DELETE"
    request.addValue("Bearer \(settings.syncToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    try validateHTTPResponse(response, data: data)
  }

  private func push(records: [DoseRecord], to baseURL: URL, settings: SettingsManager) async throws {
    var request = URLRequest(url: baseURL.appending(path: "v1/sync/push"))
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.addValue("Bearer \(settings.syncToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(
      SyncPushRequest(
        clientId: settings.deviceName.isEmpty ? "gTimer" : settings.deviceName,
        changes: SyncChanges(doses: records.map(syncPayload(for:)))
      )
    )

    let (_, response) = try await URLSession.shared.data(for: request)
    try validateHTTPResponse(response)
  }

  private func pull(from baseURL: URL, settings: SettingsManager) async throws -> SyncPullResponse {
    var components = URLComponents(
      url: baseURL.appending(path: "v1/sync/pull"),
      resolvingAgainstBaseURL: false
    )
    components?.queryItems = [
      URLQueryItem(name: "since", value: "\(settings.syncCursor)"),
      URLQueryItem(name: "limit", value: "200")
    ]
    guard let url = components?.url else { throw SyncError.invalidURL }
    var request = URLRequest(url: url)
    request.addValue("Bearer \(settings.syncToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    try validateHTTPResponse(response)
    return try JSONDecoder().decode(SyncPullResponse.self, from: data)
  }

  private func authenticate(
    path: String,
    email: String,
    password: String,
    deviceName: String,
    settings: SettingsManager
  ) async throws -> SyncAuthResponse {
    let baseURL = try syncBaseURL(settings)
    var request = URLRequest(url: baseURL.appending(path: path))
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(
      SyncAuthRequest(
        email: email,
        password: password,
        deviceName: deviceName.isEmpty ? "gTimer" : deviceName
      )
    )

    let (data, response) = try await URLSession.shared.data(for: request)
    try validateHTTPResponse(response, data: data)
    return try JSONDecoder().decode(SyncAuthResponse.self, from: data)
  }

  private func syncBaseURL(_ settings: SettingsManager) throws -> URL {
    guard let baseURL = URL(string: settings.syncServerURL.trimmingCharacters(in: .whitespacesAndNewlines)),
          baseURL.scheme?.hasPrefix("http") == true else {
      throw SyncError.invalidURL
    }
    return baseURL
  }

  private func merge(_ remoteDoses: [SyncDosePayload], context: ModelContext) {
    guard !remoteDoses.isEmpty else { return }
    let localRecords = (try? context.fetch(FetchDescriptor<DoseRecord>())) ?? []
    var localByID: [String: DoseRecord] = [:]
    for record in localRecords {
      localByID[record.id.uuidString.lowercased()] = record
    }

    for remote in remoteDoses {
      guard let remoteID = UUID(uuidString: remote.id),
            let remoteUpdatedAt = date(from: remote.updatedAt) else { continue }

      if let existing = localByID[remote.id.lowercased()] {
        let localUpdatedAt = effectiveUpdatedAt(for: existing)
        guard remoteUpdatedAt >= localUpdatedAt else { continue }
        apply(remote, to: existing)
        existing.lastSyncedAt = Date()
      } else {
        let record = DoseRecord(
          id: remoteID,
          amount: remote.amount,
          unit: remote.unit,
          time: date(from: remote.time) ?? remoteUpdatedAt,
          deviceName: remote.deviceName,
          notes: remote.notes,
          missed: remote.missed,
          edited: remote.edited,
          earlyBySeconds: remote.earlyBySeconds,
          latitude: remote.latitude,
          longitude: remote.longitude,
          locationName: remote.locationName,
          locationAccuracyMeters: remote.locationAccuracyMeters,
          locationCapturedAt: remote.locationCapturedAt.flatMap(date(from:)),
          locationSource: remote.locationSource,
          createdAt: date(from: remote.createdAt) ?? remoteUpdatedAt,
          updatedAt: remoteUpdatedAt,
          deletedAt: remote.deletedAt.flatMap(date(from:)),
          lastSyncedAt: Date()
        )
        context.insert(record)
        localByID[remote.id.lowercased()] = record
      }
    }
  }

  private func apply(_ remote: SyncDosePayload, to record: DoseRecord) {
    let updatedAt = date(from: remote.updatedAt) ?? Date()
    record.amount = remote.amount
    record.unit = remote.unit
    record.time = date(from: remote.time) ?? record.time
    record.deviceName = remote.deviceName
    record.notes = remote.notes
    record.missed = remote.missed
    record.edited = remote.edited
    record.earlyBySeconds = remote.earlyBySeconds
    record.latitude = remote.latitude
    record.longitude = remote.longitude
    record.locationName = remote.locationName
    record.locationAccuracyMeters = remote.locationAccuracyMeters
    record.locationCapturedAt = remote.locationCapturedAt.flatMap(date(from:))
    record.locationSource = remote.locationSource
    record.createdAt = date(from: remote.createdAt) ?? record.createdAt ?? record.time
    record.updatedAt = updatedAt
    record.deletedAt = remote.deletedAt.flatMap(date(from:))
  }

  private func syncPayload(for record: DoseRecord) -> SyncDosePayload {
    SyncDosePayload(
      id: record.id.uuidString,
      amount: record.amount,
      unit: record.unit,
      time: string(from: record.time),
      deviceName: record.deviceName,
      notes: record.notes,
      missed: record.missed,
      edited: record.edited,
      earlyBySeconds: record.earlyBySeconds,
      latitude: record.latitude,
      longitude: record.longitude,
      locationName: record.locationName,
      locationAccuracyMeters: record.locationAccuracyMeters,
      locationCapturedAt: record.locationCapturedAt.map(string(from:)),
      locationSource: record.locationSource,
      createdAt: string(from: record.createdAt ?? record.time),
      updatedAt: string(from: effectiveUpdatedAt(for: record)),
      deletedAt: record.deletedAt.map(string(from:))
    )
  }

  private func effectiveUpdatedAt(for record: DoseRecord) -> Date {
    record.updatedAt ?? record.createdAt ?? record.time
  }

  private func string(from date: Date) -> String {
    dateFormatter.string(from: date)
  }

  private func date(from string: String) -> Date? {
    dateFormatter.date(from: string) ?? fallbackDateFormatter.date(from: string)
  }

  private func validateHTTPResponse(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      throw SyncError.httpStatus(http.statusCode)
    }
  }

  private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
    guard let http = response as? HTTPURLResponse else { throw SyncError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
      if let apiError = try? JSONDecoder().decode(SyncAPIError.self, from: data),
         !apiError.error.isEmpty {
        throw SyncError.apiMessage(apiError.error)
      }
      throw SyncError.httpStatus(http.statusCode)
    }
  }
}

private enum SyncError: LocalizedError {
  case invalidURL
  case invalidResponse
  case httpStatus(Int)
  case apiMessage(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL: "The sync server URL is invalid."
    case .invalidResponse: "The sync server did not return a valid response."
    case .httpStatus(let status): "The sync server returned \(status)."
    case .apiMessage(let message): message
    }
  }
}

struct SyncDevice: Codable, Identifiable, Hashable {
  var id: String
  var name: String
  var createdAt: String
  var lastSeenAt: String?
  var revokedAt: String?

  var isRevoked: Bool { revokedAt != nil }
}

struct SyncAuthResponse: Codable {
  var token: String
  var user: SyncUser
  var device: SyncDevice
}

struct SyncUser: Codable {
  var id: String
  var email: String
}

private struct SyncAuthRequest: Codable {
  var email: String
  var password: String
  var deviceName: String
}

private struct SyncDevicesResponse: Codable {
  var devices: [SyncDevice]
}

private struct SyncAPIError: Codable {
  var error: String
}

private struct SyncPushRequest: Codable {
  var clientId: String
  var changes: SyncChanges
}

private struct SyncPullResponse: Codable {
  var cursor: Int
  var hasMore: Bool
  var changes: SyncChanges
}

private struct SyncChanges: Codable {
  var doses: [SyncDosePayload] = []
  var settings: [SyncIgnoredPayload] = []
  var savedLocations: [SyncIgnoredPayload] = []
  var profiles: [SyncIgnoredPayload] = []
}

private struct SyncIgnoredPayload: Codable {}

private struct SyncDosePayload: Codable {
  var id: String
  var amount: Double
  var unit: String
  var time: String
  var deviceName: String
  var notes: String
  var missed: Bool
  var edited: Bool
  var earlyBySeconds: Double?
  var latitude: Double?
  var longitude: Double?
  var locationName: String?
  var locationAccuracyMeters: Double?
  var locationCapturedAt: String?
  var locationSource: String?
  var createdAt: String
  var updatedAt: String
  var deletedAt: String?
}
