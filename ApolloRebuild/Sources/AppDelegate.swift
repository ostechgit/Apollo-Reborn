import UIKit
import UserNotifications

// AppDelegate - main app delegate
// Reconstructed from apollo-base 1.15.11 binary analysis.

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Points RDKClient at the saved Reddit app before any screen loads
        _ = AccountManager.shared
        
        // Register for remote notifications
        if #available(iOS 10.0, *) {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.badge, .sound, .alert]) { granted, error in
                if granted {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }

    // MARK: - UISceneSession Lifecycle

    // The generated Info.plist's UISceneConfigurations is empty, so without this
    // UIKit never instantiates SceneDelegate and no window is created.
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .sound, .alert])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
