import Foundation

// AstraThemeManager - manages Astra theme (dark/light mode)
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AstraThemeManager {
    
    static let shared = AstraThemeManager()
    
    private var isDarkMode: Bool = false
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved theme preference
        self.isDarkMode = defaults.bool(forKey: "astraDarkMode")
    }
    
    func setDarkMode(_ darkMode: Bool) {
        self.isDarkMode = darkMode
        self.defaults.set(darkMode, forKey: "astraDarkMode")
    }
    
    func isDark() -> Bool {
        return self.isDarkMode
    }
}
