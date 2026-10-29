import UIKit

// ThemeManager - manages app theming (light/dark mode, custom themes)
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ThemeManager {
    
    static let shared = ThemeManager()
    
    private var currentTheme: Theme = .system
    private var isDarkMode: Bool = false
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved theme preference
        let themeString = defaults.string(forKey: "theme") ?? "system"
        switch themeString {
        case "dark":
            self.currentTheme = .dark
            self.isDarkMode = true
        case "light":
            self.currentTheme = .light
            self.isDarkMode = false
        default:
            self.currentTheme = .system
            // Use UIScreen to detect dark mode on iOS 15.0
            self.isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        }
    }
    
    enum Theme {
        case system
        case light
        case dark
        case custom(color: UIColor)
    }
    
    func setTheme(_ theme: Theme) {
        self.currentTheme = theme
        
        switch theme {
        case .system:
            self.isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
            self.defaults.set("system", forKey: "theme")
        case .light:
            self.isDarkMode = false
            self.defaults.set("light", forKey: "theme")
        case .dark:
            self.isDarkMode = true
            self.defaults.set("dark", forKey: "theme")
        case .custom:
            self.isDarkMode = true
            self.defaults.set("custom", forKey: "theme")
        }
        
        // Apply theme to all windows
        applyTheme()
    }
    
    func applyTheme() {
        for window in UIApplication.shared.windows {
            if self.isDarkMode {
                window.overrideUserInterfaceStyle = .dark
            } else {
                window.overrideUserInterfaceStyle = .light
            }
        }
    }
    
    func isDark() -> Bool {
        return self.isDarkMode
    }
    
    func accentColor() -> UIColor {
        // In the original app, this would return the custom theme's accent color
        // For now, return system blue
        return UIColor.systemBlue
    }
}
