import UserNotifications
import Foundation

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
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

  private override init() {
    super.init()
  }

  func configure() {
    UNUserNotificationCenter.current().delegate = self
  }

  func requestPermission(lockScreenDelivery: Bool = false) async -> Bool {
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    _ = lockScreenDelivery
    do {
      return try await UNUserNotificationCenter.current()
        .requestAuthorization(options: options)
    } catch {
      return false
    }
  }

  func scheduleRedoseReminder(after doseTime: Date, intervalMinutes: Int, lockScreenDelivery: Bool = false) {
    cancelRedoseReminder()
    let fireDate = doseTime.addingTimeInterval(Double(intervalMinutes) * 60)
    guard fireDate > Date() else { return }

    let content = UNMutableNotificationContent()
    content.title = "Your minimum time between doses has passed"
    content.body = nextHarmReductionMessage()
    content.sound = .default
    _ = lockScreenDelivery

    let interval = fireDate.timeIntervalSinceNow
    guard interval > 0 else { return }
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: reminderIdentifier, content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request) { error in
      if let error {
        print("Failed to schedule redose reminder: \(error.localizedDescription)")
      }
    }
  }

  func cancelRedoseReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
  }

  func authorizationStatusMessage() async -> String {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    switch settings.authorizationStatus {
    case .authorized:
      return "Notifications are allowed."
    case .provisional:
      return "Notifications are allowed quietly."
    case .ephemeral:
      return "Notifications are allowed for this session."
    case .denied:
      return "Notifications are blocked in system settings."
    case .notDetermined:
      return "Notification permission has not been requested yet."
    @unknown default:
      return "Notification permission status is unknown."
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, macOS 11.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  private func nextHarmReductionMessage() -> String {
    let defaults = UserDefaults.standard
    let index = defaults.integer(forKey: messageIndexKey)
    let message = harmReductionMessages[index % harmReductionMessages.count]
    defaults.set((index + 1) % harmReductionMessages.count, forKey: messageIndexKey)
    return message
  }
}
