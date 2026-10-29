import UIKit

// SceneDelegate - manages the app's scene lifecycle
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ApolloTabBarController()
        window.makeKeyAndVisible()
        self.window = window
        
        // Apply saved theme
        ThemeManager.shared.applyTheme()
    }
}
