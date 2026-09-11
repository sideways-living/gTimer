import UserNotifications
import Foundation

final class NotificationManager {
  static let shared = NotificationManager()
  private let reminderIdentifier = "redose_reminder"
  private let messageIndexKey = "redoseReminderMessageIndex"
  private let harmReductionMessages = [
    "Stay mindful of your choices",
    "Please consider your wellbeing before any decision.",
    "Make informed choices.",
    "This is a reminder, not a recommendation.",
    "Ask yourself 'Do I need another dose right now?'"
  ]

  func requestPermission(lockScreenDelivery: Bool = false) async {
    var options: UNAuthorizationOptions = [.alert, .sound, .badge]
    #if os(iOS)
    if lockScreenDelivery {
      if #available(iOS 15.0, *) {
        options.insert(.timeSensitive)
      }
    }
    #endif
    _ = try? await UNUserNotificationCenter.current()
      .requestAuthorization(options: options)
  }

  func scheduleRedoseReminder(after doseTime: Date, intervalMinutes: Int, lockScreenDelivery: Bool = false) {
    cancelRedoseReminder()
    let fireDate = doseTime.addingTimeInterval(Double(intervalMinutes) * 60)
    guard fireDate > Date() else { return }

    let content = UNMutableNotificationContent()
    content.title = "Your minimum time between doses has passed"
    content.body = nextHarmReductionMessage()
    content.sound = .default
    #if os(iOS)
    if lockScreenDelivery {
      if #available(iOS 15.0, *) {
        content.interruptionLevel = .timeSensitive
      }
    }
    #endif

    let interval = fireDate.timeIntervalSinceNow
    guard interval > 0 else { return }
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  func cancelRedoseReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
  }

  private func nextHarmReductionMessage() -> String {
    let defaults = UserDefaults.standard
    let index = defaults.integer(forKey: messageIndexKey)
    let message = harmReductionMessages[index % harmReductionMessages.count]
    defaults.set((index + 1) % harmReductionMessages.count, forKey: messageIndexKey)
    return message
  }
}
