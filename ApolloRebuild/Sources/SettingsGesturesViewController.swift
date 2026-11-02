import UIKit
import Eureka

// SettingsGesturesViewController - Apollo's swipe-action configuration.
//
// Reconstructed from apollo-base 1.15.11 (`SettingsGesturesViewController`,
// `_TtC6Apollo30SettingsGesturesViewController`). The original lists one row per
// slide-gesture slot, each showing the currently assigned action, plus a
// "Long Swipe Trigger Point" row and a "Restore Default Swipe Actions" action.
//
// The slots are per-context: Apollo keeps a separate four-element array for
// posts, comments, profile posts, profile comments and inbox comments (see
// `SlideGestureSettings`).

class SettingsGesturesViewController: FormViewController {

    /// Titles in the order `SlideGestureAction.allCases` declares them; each is
    /// unique, which is what lets a row map a display title back to an action.
    private static let actionTitles: [String] = SlideGestureAction.allCases.map(\.title)

    private static func action(forTitle title: String?) -> SlideGestureAction? {
        guard let title = title else { return nil }
        return SlideGestureAction.allCases.first { $0.title == title }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Gestures"
        self.buildForm()
    }

    private func buildForm() {
        self.form = Form()

        for context in SlideGestureContext.allCases {
            let section = Section(context.title)
            for point in SlideGesturePoint.allCases {
                let tag = "\(context.rawValue).\(point.rawValueString)"
                section.append(
                    ActionSheetRow<String>(tag) { row in
                        row.title = point.title
                        row.options = Self.actionTitles
                        row.value = SlideGestureSettings.action(at: point, for: context).title
                        row.onChange { row in
                            guard let action = Self.action(forTitle: row.value) else { return }
                            SlideGestureSettings.setAction(action, at: point, for: context)
                        }
                    }
                )
            }
            self.form.append(section)
        }

        let triggerSection = Section(footer: "When the long swipe action should trigger.")
        triggerSection.append(
            ActionSheetRow<String>("longSwipeTriggerPoint") { row in
                row.title = "Long Swipe Trigger Point"
                row.options = LongSwipeTriggerPoint.allCases.map(\.rawValue).map {
                    LongSwipeTriggerPoint(rawValue: $0)?.title ?? $0
                }
                row.value = SlideGestureSettings.longSwipeTriggerPoint.title
                row.onChange { row in
                    guard let title = row.value,
                          let point = LongSwipeTriggerPoint.allCases.first(where: { $0.title == title })
                    else { return }
                    SlideGestureSettings.longSwipeTriggerPoint = point
                }
            }
        )
        self.form.append(triggerSection)

        let resetSection = Section()
        resetSection.append(
            ButtonRow("restoreDefaults") { row in
                row.title = "Restore Default Swipe Actions"
                row.onCellSelection { [weak self] _, _ in
                    SlideGestureSettings.restoreDefaults()
                    self?.buildForm()
                }
            }
        )
        self.form.append(resetSection)
    }
}
