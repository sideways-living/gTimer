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

  private func successDialog(for result: AssistedDoseLoggingResult) -> String {
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
  }
}
