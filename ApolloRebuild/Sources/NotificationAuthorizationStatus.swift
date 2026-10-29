import Foundation
import UserNotifications

// NotificationAuthorizationStatus - checks notification authorization status
// Reconstructed from apollo-base 1.15.11 binary analysis.

class NotificationAuthorizationStatus {
    
    static let shared = NotificationAuthorizationStatus()
    
    private init() {}
    
    func isAuthorized(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.badge, .sound, .alert]
        ) { granted, error in
            if let error = error {
                LogBuddy.error("Notification authorization error: \(error)")
            }
        }
    }
}
