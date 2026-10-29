import UIKit
import Eureka

// SettingsGeneralViewController - general settings page
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SettingsGeneralViewController: FormViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "General"
        
        // Build the general settings form
        buildForm()
    }
    
    private func buildForm() {
        self.form = Form()
        
        // Theme section
        let themeSection = Section("Theme")
        themeSection.append(
            SwitchRow("darkMode") { row in
                row.title = "Dark Mode"
                row.value = false
            }
        )
        self.form.append(themeSection)
        
        // Display section
        let displaySection = Section("Display")
        displaySection.append(
            SwitchRow("compactMode") { row in
                row.title = "Compact Mode"
                row.value = false
            }
        )
        displaySection.append(
            SwitchRow("showNSFW") { row in
                row.title = "Show NSFW"
                row.value = false
            }
        )
        self.form.append(displaySection)
        
        // Notifications section
        let notificationsSection = Section("Notifications")
        notificationsSection.append(
            SwitchRow("pushNotifications") { row in
                row.title = "Push Notifications"
                row.value = true
            }
        )
        self.form.append(notificationsSection)
    }
}
