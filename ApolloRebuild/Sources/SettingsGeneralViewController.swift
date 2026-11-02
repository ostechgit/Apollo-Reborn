import UIKit
import Eureka

// SettingsGeneralViewController - Apollo's General settings page.
//
// Rebuilt from the base binary: the row titles and the defaults keys behind them
// were both read out of the same builder function in
// `SettingsGeneralViewController` (`method_5` for autoplay, `method_6` for
// auto-collapse, `method_1` for the AutoModerator row). Only rows whose key and
// option values could be evidenced are present here — see the note at the bottom
// for what stock has that is still missing.

class SettingsGeneralViewController: FormViewController {

    private static let autoplayValues = ["always", "only-on-wifi", "never"]

    private static func autoplayTitle(_ value: String?) -> String {
        switch value {
        case "only-on-wifi": return "WiFi Only"
        case "never": return "Never"
        default: return "Always"
        }
    }

    private static func autoplayValue(_ title: String?) -> String {
        switch title {
        case "WiFi Only": return "only-on-wifi"
        case "Never": return "never"
        default: return "always"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "General"
        self.buildForm()
    }

    private func buildForm() {
        self.form = Form()

        let playback = Section()
        playback.append(
            ActionSheetRow<String>("autoplay") { row in
                row.title = "Autoplay GIFs/Videos…"
                row.options = ["Always", "WiFi Only", "Never"]
                let stored = UserDefaults.standard.string(forKey: "AutoplayGIFs") ?? "always"
                row.value = Self.autoplayTitle(stored)
                row.onChange { row in
                    UserDefaults.standard.set(Self.autoplayValue(row.value), forKey: "AutoplayGIFs")
                }
            }
        )
        playback.append(
            SwitchRow("autoplayCellular") { row in
                row.title = "Autoplay over Cellular"
                row.value = UserDefaults.standard.object(forKey: "AutoplayGifsOverCellular") as? Bool ?? false
                row.onChange { row in
                    UserDefaults.standard.set(row.value ?? false, forKey: "AutoplayGifsOverCellular")
                }
            }
        )
        self.form.append(playback)

        let comments = Section(footer: "Applies to replies to top-level comments.")
        comments.append(
            ActionSheetRow<String>("autoCollapse") { row in
                row.title = "Auto Collapse Replies"
                row.options = ["Manually", "Remember Subreddit"]
                let stored = UserDefaults.standard.string(forKey: "AutoCollapseChildComments") ?? "manually"
                row.value = stored == "rememberSubreddit" ? "Remember Subreddit" : "Manually"
                row.onChange { row in
                    let value = row.value == "Remember Subreddit" ? "rememberSubreddit" : "manually"
                    UserDefaults.standard.set(value, forKey: "AutoCollapseChildComments")
                }
            }
        )
        self.form.append(comments)

        // Stock warns before enabling this: collapsing AutoModerator comments can
        // hide a moderator's message from the user.
        let automod = Section()
        automod.append(
            SwitchRow("autoCollapseAutoMod") { row in
                row.title = "Automatically Collapse AutoModerator Comments"
                row.value = UserDefaults.standard.bool(forKey: "AutoCollapseAutoModeratorComments")
                row.onChange { [weak self] row in
                    guard row.value == true else {
                        UserDefaults.standard.set(false, forKey: "AutoCollapseAutoModeratorComments")
                        return
                    }
                    let alert = UIAlertController(
                        title: nil,
                        message: "Automatically collapsing these comments may cause you to miss an "
                            + "important message from a Moderator.",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                        row.value = false
                        row.updateCell()
                    })
                    alert.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
                        UserDefaults.standard.set(true, forKey: "AutoCollapseAutoModeratorComments")
                    })
                    self?.present(alert, animated: true)
                }
            }
        )
        self.form.append(automod)
    }
}

// Stock's General screen also carries rows that are not reproduced yet because
// their titles sit in unnamed functions and only their defaults are known:
//
//   Default Reddit to Load…        (multireddit / subreddit picker)
//   Open Links In                  OpenLinksIn            default "in-app-safari"
//   Haptic Feedback                HapticFeedback         default true
//   Clear Cache                    action, no stored value
//
// See Apollo-Source-Private/RE/settings-reference.md.
