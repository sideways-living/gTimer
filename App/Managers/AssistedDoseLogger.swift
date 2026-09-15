import Foundation
import SwiftData
import CoreLocation

struct AssistedDoseLoggingInput {
  var amount: Double
  var unit: String?
  var spokenDetails: String?
  var explicitTime: Date?
  var explicitLocationName: String?
  var explicitPeople: String?
  var explicitTags: String?
  var explicitNotes: String?
  var missed: Bool
}

struct AssistedDoseLoggingResult {
  var amount: Double
  var unit: String
  var time: Date
  var missed: Bool
  var tags: [String]
  var people: [String]
  var locationName: String?
  var usedCurrentLocation: Bool
}

enum AssistedDoseLoggingError: LocalizedError {
  case disabled
  case missingAmount
  case invalidAmount
  case storeUnavailable

  var errorDescription: String? {
    switch self {
    case .disabled:
      "Siri and AI dose logging is a gTimer Pro feature. Turn it on in Settings after activating gTimer Pro."
    case .missingAmount:
      "Tell gTimer the dose amount to log."
    case .invalidAmount:
      "The dose amount must be greater than zero."
    case .storeUnavailable:
      "gTimer could not open the dose store."
    }
  }
}

@MainActor
enum AssistedDoseLogger {
  static func log(_ input: AssistedDoseLoggingInput) async throws -> AssistedDoseLoggingResult {
    let settings = SettingsManager.shared
    guard settings.proBetaAccepted, settings.voiceDoseLoggingEnabled else {
      throw AssistedDoseLoggingError.disabled
    }

    let parsed = AssistedDoseCommandParser.parse(input)
    guard parsed.amountWasProvided else { throw AssistedDoseLoggingError.missingAmount }
    guard parsed.amount > 0 else { throw AssistedDoseLoggingError.invalidAmount }

    let container = try ModelContainer(for: DoseRecord.self)
    let context = ModelContext(container)
    let records = (try? context.fetch(FetchDescriptor<DoseRecord>(
      sortBy: [SortDescriptor(\.time, order: .reverse)]
    ))) ?? []

    ManualLocationStore.shared.absorbHistoryLocations(from: records)

    let resolvedLocation = await AssistedDoseLocationResolver.resolve(
      spokenLocationName: parsed.locationName,
      records: records,
      settings: settings
    )
    let locationName = resolvedLocation.name
    let capturedLocation = resolvedLocation.location
    let source = resolvedLocation.source
    let logTime = parsed.time
    let isMissed = parsed.missed || logTime < Date().addingTimeInterval(-5 * 60)
    let earlyBy = isMissed ? nil : earlyBySeconds(for: logTime, records: records, settings: settings)

    DoseStore.logDose(
      amount: parsed.amount,
      unit: parsed.unit,
      time: logTime,
      notes: parsed.notes,
      tags: parsed.tags,
      people: parsed.people,
      missed: isMissed,
      earlyBySeconds: earlyBy,
      capturedLocation: capturedLocation,
      locationName: locationName,
      locationSource: source,
      deviceName: settings.deviceName,
      context: context,
      settings: settings
    )

    if let capturedLocation, let locationName, !locationName.isEmpty {
      ManualLocationStore.shared.save(
        name: locationName,
        latitude: capturedLocation.coordinate.latitude,
        longitude: capturedLocation.coordinate.longitude
      )
    }

    return AssistedDoseLoggingResult(
      amount: parsed.amount,
      unit: parsed.unit,
      time: logTime,
      missed: isMissed,
      tags: parsed.tags,
      people: parsed.people,
      locationName: locationName,
      usedCurrentLocation: resolvedLocation.usedCurrentLocation
    )
  }

  private static func earlyBySeconds(
    for logTime: Date,
    records: [DoseRecord],
    settings: SettingsManager
  ) -> TimeInterval? {
    let previousDose = records
      .filter { !$0.isDeletedForSync && $0.time <= logTime }
      .max { $0.time < $1.time }
    guard let previousDose else { return nil }
    let elapsed = logTime.timeIntervalSince(previousDose.time)
    let minimum = Double(settings.safeIntervalMinutes) * 60
    guard elapsed >= 0, elapsed < minimum else { return nil }
    return minimum - elapsed
  }
}

private struct ParsedAssistedDoseCommand {
  var amount: Double
  var amountWasProvided: Bool
  var unit: String
  var time: Date
  var locationName: String?
  var people: [String]
  var tags: [String]
  var notes: String
  var missed: Bool
}

private enum AssistedDoseCommandParser {
  static func parse(_ input: AssistedDoseLoggingInput) -> ParsedAssistedDoseCommand {
    let settings = SettingsManager.shared
    let spoken = input.spokenDetails?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let amountMatch = firstMatch(
      pattern: #"(?i)\b([0-9]+(?:\.[0-9]+)?)\s*(ml|mg|g)?\b"#,
      in: spoken
    )
    let parsedAmount = amountMatch
      .flatMap { match in Double(capture(1, in: spoken, match: match) ?? "") }
    let parsedUnit = amountMatch
      .flatMap { capture(2, in: spoken, match: $0) }
      .map { $0.lowercased() }

    let amountWasProvided = input.amount > 0 || parsedAmount != nil
    let amount = input.amount > 0 ? input.amount : (parsedAmount ?? 0)
    let unit = input.unit?.trimmedNonEmpty ?? parsedUnit ?? settings.unit
    let parsedTime = parseTime(in: spoken)
    let time = input.explicitTime ?? parsedTime ?? Date()
    let explicitLocation = input.explicitLocationName?.trimmedNonEmpty
    let locationName = explicitLocation ?? parseLocation(in: spoken)

    let tags = (
      DoseRecord.normalizedTags(from: input.explicitTags ?? "") +
      parseTags(in: spoken)
    ).removingDuplicateStrings()
    let people = (
      DoseRecord.normalizedPeople(from: input.explicitPeople ?? "") +
      parsePeople(in: spoken)
    ).removingDuplicateStrings()

    let notes: String
    if let explicitNotes = input.explicitNotes?.trimmedNonEmpty {
      notes = explicitNotes
    } else if settings.voiceDoseStoreSpokenPhraseInNotes {
      notes = spoken
    } else {
      notes = ""
    }

    return ParsedAssistedDoseCommand(
      amount: amount,
      amountWasProvided: amountWasProvided,
      unit: unit,
      time: time,
      locationName: locationName,
      people: people,
      tags: tags,
      notes: notes,
      missed: input.missed || parsedTime != nil
    )
  }

  private static func parseTime(in text: String) -> Date? {
    guard let match = firstMatch(
      pattern: #"(?i)\bat\s+([0-9]{1,2})(?::([0-9]{2}))?\s*(am|pm)?\b"#,
      in: text
    ) else { return nil }

    guard var hour = capture(1, in: text, match: match).flatMap(Int.init) else { return nil }
    let minute = capture(2, in: text, match: match).flatMap(Int.init) ?? 0
    guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }

    if let meridiem = capture(3, in: text, match: match)?.lowercased() {
      if meridiem == "pm", hour < 12 { hour += 12 }
      if meridiem == "am", hour == 12 { hour = 0 }
    }

    let now = Date()
    let calendar = Calendar.current
    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = hour
    components.minute = minute
    components.second = 0
    guard let candidate = calendar.date(from: components) else { return nil }
    if candidate > now.addingTimeInterval(5 * 60) {
      return calendar.date(byAdding: .day, value: -1, to: candidate)
    }
    return candidate
  }

  private static func parseLocation(in text: String) -> String? {
    let pattern = #"(?i)\bat\s+(?![0-9]{1,2}(?::[0-9]{2})?\s*(?:am|pm)?\b)(.+?)(?=\s+with\s+|\s+hashtag\b|\s+hashtags\b|\s+#|$)"#
    guard let match = firstMatch(pattern: pattern, in: text),
          let value = capture(1, in: text, match: match)?.trimmedNonEmpty
    else { return nil }
    return value
  }

  private static func parsePeople(in text: String) -> [String] {
    guard let match = firstMatch(
      pattern: #"(?i)\bwith\s+(.+?)(?=\s+hashtag\b|\s+hashtags\b|\s+#|$)"#,
      in: text
    ), let value = capture(1, in: text, match: match)
    else { return [] }

    return value
      .replacingOccurrences(of: " and ", with: ", ", options: .caseInsensitive)
      .components(separatedBy: CharacterSet(charactersIn: ","))
      .map(DoseRecord.normalizedPerson)
      .filter { !$0.isEmpty }
      .removingDuplicateStrings()
  }

  private static func parseTags(in text: String) -> [String] {
    var tags: [String] = []
    tags.append(contentsOf: allMatches(pattern: #"#[A-Za-z0-9_]+"#, in: text).map {
      capture(0, in: text, match: $0) ?? ""
    })

    let phrasePattern = #"(?i)\bhashtags?\s+(.+?)(?=\s+with\s+|$)"#
    if let match = firstMatch(pattern: phrasePattern, in: text),
       let value = capture(1, in: text, match: match)?.trimmedNonEmpty {
      tags.append("#" + value.filter { $0.isLetter || $0.isNumber || $0 == "_" }.lowercased())
    }

    return DoseRecord.normalizedTags(from: tags).removingDuplicateStrings()
  }

  private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
    allMatches(pattern: pattern, in: text).first
  }

  private static func allMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
    guard !text.isEmpty,
          let regex = try? NSRegularExpression(pattern: pattern)
    else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range)
  }

  private static func capture(_ index: Int, in text: String, match: NSTextCheckingResult) -> String? {
    guard index < match.numberOfRanges else { return nil }
    let range = match.range(at: index)
    guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
    return String(text[swiftRange])
  }
}

private struct ResolvedAssistedLocation {
  var name: String?
  var location: CLLocation?
  var source: String
  var usedCurrentLocation: Bool
}

private enum AssistedDoseLocationResolver {
  static func resolve(
    spokenLocationName: String?,
    records: [DoseRecord],
    settings: SettingsManager
  ) async -> ResolvedAssistedLocation {
    let cleanName = spokenLocationName?.trimmedNonEmpty

    if let cleanName, settings.voiceDoseMatchSavedLocations {
      if let saved = ManualLocationStore.shared.suggestions(matching: cleanName, limit: 5).first {
        return saved.resolved(source: "manual")
      }
      if let recent = matchedHistoryLocation(cleanName, records: records) {
        return recent.resolved(source: "manual")
      }
    }

    let locationManager = LocationManager.shared
    var currentLocation: CLLocation?
    if settings.voiceDoseAttachCurrentLocation || cleanName != nil {
      let granted = await locationManager.requestWhenInUsePermissionIfNeeded()
      if granted {
        currentLocation = await locationManager.captureForDose(timeout: 2.5)
      }
    }

    if let cleanName,
       let currentLocation,
       (locationManager.locationName ?? "").localizedCaseInsensitiveContains(cleanName) {
      return ResolvedAssistedLocation(
        name: locationManager.locationName ?? cleanName,
        location: currentLocation,
        source: "current",
        usedCurrentLocation: true
      )
    }

    if let cleanName, settings.voiceDoseMatchSavedLocations {
      let found = await ManualLocationStore.shared.searchResults(
        matching: cleanName,
        context: settings.manualLocationSearchContext(currentCoordinate: currentLocation?.coordinate),
        limit: 1
      ).first
      if let found {
        return found.resolved(source: "manual")
      }
    }

    if let cleanName {
      return ResolvedAssistedLocation(
        name: cleanName,
        location: nil,
        source: "manual",
        usedCurrentLocation: false
      )
    }

    if settings.voiceDoseAttachCurrentLocation, let currentLocation {
      return ResolvedAssistedLocation(
        name: locationManager.locationName,
        location: currentLocation,
        source: "current",
        usedCurrentLocation: true
      )
    }

    return ResolvedAssistedLocation(
      name: nil,
      location: nil,
      source: "none",
      usedCurrentLocation: false
    )
  }

  private static func matchedHistoryLocation(_ query: String, records: [DoseRecord]) -> ManualDoseLocation? {
    records
      .filter { !$0.isDeletedForSync && $0.hasLocation }
      .prefix(30)
      .compactMap { record -> ManualDoseLocation? in
        guard let name = record.locationName,
              name.localizedCaseInsensitiveContains(query),
              let latitude = record.latitude,
              let longitude = record.longitude
        else { return nil }
        return ManualDoseLocation(name: name, latitude: latitude, longitude: longitude)
      }
      .first
  }
}

private extension ManualDoseLocation {
  func resolved(source: String) -> ResolvedAssistedLocation {
    ResolvedAssistedLocation(
      name: name,
      location: CLLocation(latitude: latitude, longitude: longitude),
      source: source,
      usedCurrentLocation: false
    )
  }
}

private extension String {
  var trimmedNonEmpty: String? {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
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
