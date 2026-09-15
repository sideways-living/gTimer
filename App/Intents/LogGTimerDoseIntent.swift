import AppIntents
import Foundation

struct LogGTimerDoseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log gTimer Dose"
  static var description = IntentDescription("Log a gTimer dose from Siri, Shortcuts, or an automation.")
  static var openAppWhenRun = false

  @Parameter(title: "Amount", description: "Dose amount. Use 0 when the amount is included in spoken details.")
  var amount: Double

  @Parameter(title: "Spoken details", description: "Example: 2.8ml at Adina with Jake hashtag working away")
  var details: String?

  @Parameter(title: "Time", description: "Leave blank to log the dose now.")
  var doseTime: Date?

  @Parameter(title: "Location", description: "A venue, address, suburb, hotel, or saved dose location.")
  var location: String?

  @Parameter(title: "People", description: "Names to link with the dose, separated by commas.")
  var people: String?

  @Parameter(title: "Tags", description: "Hashtags to attach to the dose.")
  var tags: String?

  @Parameter(title: "Notes")
  var notes: String?

  @Parameter(title: "Missed dose", default: false)
  var missed: Bool

  init() {
    amount = 0
    details = nil
    doseTime = nil
    location = nil
    people = nil
    tags = nil
    notes = nil
    missed = false
  }

  init(amount: Double) {
    self.amount = amount
    details = nil
    doseTime = nil
    location = nil
    people = nil
    tags = nil
    notes = nil
    missed = false
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      let result = try await AssistedDoseLogger.log(
        AssistedDoseLoggingInput(
          amount: amount,
          unit: nil,
          spokenDetails: details,
          explicitTime: doseTime,
          explicitLocationName: location,
          explicitPeople: people,
          explicitTags: tags,
          explicitNotes: notes,
          missed: missed
        )
      )
      return .result(dialog: IntentDialog(stringLiteral: successDialog(for: result)))
    } catch {
      return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
    }
  }

  fileprivate func successDialog(for result: AssistedDoseLoggingResult) -> String {
    var parts = [
      "Logged \(result.amount.formatted(.number.precision(.fractionLength(0...3))))\(result.unit)"
    ]
    if result.missed {
      parts.append("as a missed dose")
    }
    if let locationName = result.locationName, !locationName.isEmpty {
      parts.append("at \(locationName)")
    }
    if !result.people.isEmpty {
      parts.append("with \(result.people.joined(separator: ", "))")
    }
    if !result.tags.isEmpty {
      parts.append(result.tags.joined(separator: " "))
    }
    return parts.joined(separator: " ")
  }
}

private enum AssistedDoseIntentRunner {
  @MainActor
  static func log(_ input: AssistedDoseLoggingInput) async -> String {
    do {
      let result = try await AssistedDoseLogger.log(input)
      return LogGTimerDoseIntent().successDialog(for: result)
    } catch {
      return error.localizedDescription
    }
  }
}

struct LogGTimerStandardDoseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log gTimer Standard Dose"
  static var description = IntentDescription("Log the standard gTimer dose configured in Settings.")
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = await AssistedDoseIntentRunner.log(
      AssistedDoseLoggingInput(
        amount: 0,
        unit: nil,
        spokenDetails: nil,
        explicitTime: nil,
        explicitLocationName: nil,
        explicitPeople: nil,
        explicitTags: nil,
        explicitNotes: nil,
        missed: false,
        useStandardDose: true
      )
    )
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

struct LogGTimerTwoPointEightDoseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log gTimer 2.8ml Dose"
  static var description = IntentDescription("Log a 2.8ml gTimer dose.")
  static var openAppWhenRun = false

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = await AssistedDoseIntentRunner.log(
      AssistedDoseLoggingInput(
        amount: 2.8,
        unit: "ml",
        spokenDetails: nil,
        explicitTime: nil,
        explicitLocationName: nil,
        explicitPeople: nil,
        explicitTags: nil,
        explicitNotes: nil,
        missed: false
      )
    )
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

struct LogGTimerMissedDoseIntent: AppIntent {
  static var title: LocalizedStringResource = "Log gTimer Missed Dose"
  static var description = IntentDescription("Log a missed or backdated gTimer dose.")
  static var openAppWhenRun = false

  @Parameter(title: "Amount", description: "Dose amount. Use 0 when the amount is included in spoken details.")
  var amount: Double

  @Parameter(title: "Spoken details", description: "Example: 2.8ml at 9pm at Adina with Jake hashtag working away")
  var details: String?

  @Parameter(title: "Time", description: "Leave blank to use the time included in spoken details.")
  var doseTime: Date?

  @Parameter(title: "Location", description: "A venue, address, suburb, hotel, or saved dose location.")
  var location: String?

  @Parameter(title: "People", description: "Names to link with the dose, separated by commas.")
  var people: String?

  @Parameter(title: "Tags", description: "Hashtags to attach to the dose.")
  var tags: String?

  @Parameter(title: "Notes")
  var notes: String?

  init() {
    amount = 0
    details = nil
    doseTime = nil
    location = nil
    people = nil
    tags = nil
    notes = nil
  }

  @MainActor
  func perform() async throws -> some IntentResult & ProvidesDialog {
    let message = await AssistedDoseIntentRunner.log(
      AssistedDoseLoggingInput(
        amount: amount,
        unit: nil,
        spokenDetails: details,
        explicitTime: doseTime,
        explicitLocationName: location,
        explicitPeople: people,
        explicitTags: tags,
        explicitNotes: notes,
        missed: true
      )
    )
    return .result(dialog: IntentDialog(stringLiteral: message))
  }
}

struct GTimerAppShortcuts: AppShortcutsProvider {
  static var shortcutTileColor: ShortcutTileColor = .blue

  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogGTimerDoseIntent(),
      phrases: [
        "Get \(.applicationName) to log a dose",
        "Log a dose in \(.applicationName)"
      ],
      shortTitle: "Log Dose",
      systemImageName: "drop.fill"
    )
    AppShortcut(
      intent: LogGTimerStandardDoseIntent(),
      phrases: [
        "Get \(.applicationName) to log my standard dose",
        "Log my standard dose in \(.applicationName)"
      ],
      shortTitle: "Standard Dose",
      systemImageName: "drop.circle.fill"
    )
    AppShortcut(
      intent: LogGTimerTwoPointEightDoseIntent(),
      phrases: [
        "Get \(.applicationName) to log two point eight ml",
        "Log two point eight ml in \(.applicationName)"
      ],
      shortTitle: "2.8ml Dose",
      systemImageName: "plus.circle.fill"
    )
    AppShortcut(
      intent: LogGTimerMissedDoseIntent(),
      phrases: [
        "Get \(.applicationName) to log a missed dose",
        "Log a missed dose in \(.applicationName)"
      ],
      shortTitle: "Missed Dose",
      systemImageName: "clock.badge.exclamationmark.fill"
    )
  }
}
