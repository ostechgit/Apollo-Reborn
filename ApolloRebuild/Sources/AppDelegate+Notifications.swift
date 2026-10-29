import Foundation
import UserNotifications

// AppDelegate+Notifications - APNs token handling for push notifications
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original function signatures recovered from RE:
// - fetchAPNsToken(completion:)
// - application(_:didRegisterForRemoteNotificationsWithDeviceToken:)
// - application(_:didFailToRegisterForRemoteNotificationsWithError:)

extension AppDelegate {
    
    // Fetches the APNs device token for push notifications
    // completion: Called with the token string or nil on failure
    func fetchAPNsToken(completion: @escaping (String?) -> Void) {
        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if !granted {
                completion(nil)
                return
            }
            
            // Register for remote notifications
            UIApplication.shared.registerForRemoteNotifications()
            
            // Store the completion handler to be called when the token arrives
            self.apnsTokenCompletion = completion
        }
    }
    
    // Called by iOS when the device token is received
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert token to hex string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        // Store the token (in original, this went to ServerBuddy for registration)
        UserDefaults.standard.set(tokenString, forKey: "APNsDeviceToken")
        
        // Call the completion handler if one is waiting
        if let completion = self.apnsTokenCompletion {
            completion(tokenString)
            self.apnsTokenCompletion = nil
        }
    }
    
    // Called by iOS when registration fails
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
        
        // Call the completion handler with nil
        if let completion = self.apnsTokenCompletion {
            completion(nil)
            self.apnsTokenCompletion = nil
        }
    }
}

// Property to store the pending APNs token completion handler
private var apnsTokenCompletionKey: UInt8 = 0
extension AppDelegate {
    var apnsTokenCompletion: ((String?) -> Void)? {
        get {
            return objc_getAssociatedObject(self, &apnsTokenCompletionKey) as? ((String?) -> Void)
        }
        set {
            objc_setAssociatedObject(self, &apnsTokenCompletionKey, newValue, .OBJC_ASSOCIATION_COPY)
        }
    }
}
