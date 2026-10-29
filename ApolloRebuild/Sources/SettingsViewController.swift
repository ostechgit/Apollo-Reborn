import UIKit
import Eureka

// SettingsViewController - app settings
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SettingsViewController: FormViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Settings"
        
        // Build the settings form
        buildForm()
    }
    
    private func buildForm() {
        self.form = Form()
        
        // General section
        let generalSection = Section("General")
        generalSection.append(
            SwitchRow("theme") { row in
                row.title = "Dark Mode"
                row.value = ThemeManager.shared.isDark()
                row.onChange { row in
                    if row.value == true {
                        ThemeManager.shared.setTheme(.dark)
                    } else {
                        ThemeManager.shared.setTheme(.light)
                    }
                }
            }
        )
        generalSection.append(
            SwitchRow("notifications") { row in
                row.title = "Notifications"
                row.value = true
            }
        )
        generalSection.append(
            SwitchRow("animations") { row in
                row.title = "Animations"
                row.value = true
            }
        )
        self.form.append(generalSection)
        
        // Display section
        let displaySection = Section("Display")
        displaySection.append(
            SwitchRow("compact") { row in
                row.title = "Compact Mode"
                row.value = false
            }
        )
        displaySection.append(
            SwitchRow("nsfw") { row in
                row.title = "Show NSFW"
                row.value = false
            }
        )
        self.form.append(displaySection)
        
        // About section
        let aboutSection = Section("About")
        aboutSection.append(
            LabelRow("version") { row in
                row.title = "Version"
                row.value = "1.15.11"
            }
        )
        self.form.append(aboutSection)
    }
}
