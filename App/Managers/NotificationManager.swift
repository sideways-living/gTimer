import UserNotifications
import Foundation

final class NotificationManager {
  static let shared = NotificationManager()

  func requestPermission() async {
    _ = try? await UNUserNotificationCenter.current()
      .requestAuthorization(options: [.alert, .sound, .badge])
  }

  func scheduleRedoseReminder(after doseTime: Date, intervalMinutes: Int) {
    cancelRedoseReminder()
    let fireDate = doseTime.addingTimeInterval(Double(intervalMinutes) * 60)
    guard fireDate > Date() else { return }

    let content = UNMutableNotificationContent()
    content.title = "G Timer – Safe to Redose"
    content.body = "Your safe interval has passed. Stay safe."
    content.sound = .default

    let interval = fireDate.timeIntervalSinceNow
    guard interval > 0 else { return }
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
    let request = UNNotificationRequest(identifier: "redose_reminder", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
  }

  func cancelRedoseReminder() {
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["redose_reminder"])
  }
}
