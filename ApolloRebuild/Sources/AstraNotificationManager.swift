import Foundation
import UserNotifications

// AstraNotificationManager - manages notifications for the app
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AstraNotificationManager {
    
    static let shared = AstraNotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.badge, .sound, .alert]
        ) { granted, error in
            if let error = error {
                LogBuddy.error("Notification authorization error: \(error)")
            }
        }
    }
    
    func scheduleNotification(title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogBuddy.error("Failed to schedule notification: \(error)")
            }
        }
    }
}
