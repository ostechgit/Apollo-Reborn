import UIKit
import Eureka

// SettingsViewController - the root Settings list.
//
// Stock's row set was recovered from the icon asset each row loads
// (`settings-account-`, `settings-appearance`, `settings-general-`, …) plus the
// decoded titles; see Apollo-Source-Private/RE/settings-reference.md.
//
// Only destinations that exist in this rebuild are listed. Creating empty
// screens for the rest would put fabricated UI in front of the user, so they are
// deliberately absent until built.

class SettingsViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Settings"
        self.buildForm()
    }

    private func push(_ controller: UIViewController) {
        self.navigationController?.pushViewController(controller, animated: true)
    }

    private func buildForm() {
        self.form = Form()

        let browsing = Section()
        browsing.append(
            ButtonRow("appearance") { row in
                row.title = "Appearance"
                row.onCellSelection { [weak self] _, _ in
                    self?.push(SettingsAppearanceViewController())
                }
            }
        )
        browsing.append(
            ButtonRow("general") { row in
                row.title = "General"
                row.onCellSelection { [weak self] _, _ in
                    self?.push(SettingsGeneralViewController())
                }
            }
        )
        browsing.append(
            ButtonRow("gestures") { row in
                row.title = "Gestures"
                row.onCellSelection { [weak self] _, _ in
                    self?.push(SettingsGesturesViewController())
                }
            }
        )
        browsing.append(
            ButtonRow("filters") { row in
                row.title = "Filters & Blocks"
                row.onCellSelection { [weak self] _, _ in
                    self?.push(SettingsFiltersViewController())
                }
            }
        )
        self.form.append(browsing)

        let about = Section()
        about.append(
            ButtonRow("about") { row in
                row.title = "About"
                row.onCellSelection { [weak self] _, _ in
                    self?.push(SettingsAboutViewController())
                }
            }
        )
        self.form.append(about)
    }
}

// Stock's root Settings list, in order, with the asset that identifies each row.
// Rows marked "missing" have no screen in this rebuild yet:
//
//   Account / Add Account        settings-account-          missing
//   Apollo Ultra                 settings-apollo-ultra      missing
//   Appearance                   settings-appearance        built
//   General                      settings-general-          built
//   Gestures                     settings-gestures-         built
//   Filters & Blocks             settings-blocks-           placeholder screen
//   Notifications                settings-notifications-light  missing
//   Face ID & Passcode           settings-face-id-          missing
//   Touch ID & Passcode          settings-touch-id-         missing
//   Passcode                     settings-passcode-         missing
//   Tip Jar                      settings-tip-jar-green     missing
//   About                        settings-about-            placeholder screen
//
// The biometric row title is chosen at runtime: Face ID and Touch ID are separate
// assets resolving to the same screen.
