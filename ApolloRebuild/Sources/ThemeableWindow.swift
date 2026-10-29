import UIKit

// ThemeableWindow - a window that supports theming
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ThemeableWindow: UIWindow {
    
    override var backgroundColor: UIColor? {
        get {
            return super.backgroundColor
        }
        set {
            super.backgroundColor = newValue
        }
    }
    
    func applyTheme(_ theme: ThemeManager.Theme) {
        switch theme {
        case .dark:
            self.backgroundColor = UIColor.black
        case .light:
            self.backgroundColor = UIColor.white
        default:
            self.backgroundColor = UIColor.systemBackground
        }
    }
}
