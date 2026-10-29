import UIKit

// UIApplication+Extras - extension with additional utility methods
// Reconstructed from apollo-base 1.15.11 binary analysis.

extension UIApplication {
    
    var topViewController: UIViewController? {
        var topVC = self.keyWindow?.rootViewController
        
        while let presentedVC = topVC?.presentedViewController {
            topVC = presentedVC
        }
        
        // Handle navigation controllers
        if let navVC = topVC as? UINavigationController {
            topVC = navVC.topViewController
        }
        
        // Handle tab bar controllers
        if let tabVC = topVC as? UITabBarController {
            topVC = tabVC.selectedViewController
        }
        
        return topVC
    }
}
