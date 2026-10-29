import UIKit

// ActionController+Report - general post/comment reporting
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original function signatures recovered from RE:
// - reportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)

extension ActionController {
    
    // Show general report options for a thing (post or comment)
    func reportSubredditRulesSelected(thingFullname: String,
                                     subreddit: String,
                                     tintAsModerator: Bool = false,
                                     fromViewController viewController: UIViewController) {
        
        // Fetch subreddit rules to show as report options
        RDKClient.shared.subredditWithName(subreddit) { [weak self] subredditObj, error in
            if let subredditObj = subredditObj, let rules = subredditObj.rules {
                // Show rules as report options
                self?.showReportRulesForThing(rules: rules, thingFullname: thingFullname, subreddit: subreddit, fromViewController: viewController)
            } else {
                // No rules, show generic report options
                self?.showGenericReportOptionsForThing(thingFullname: thingFullname, subreddit: subreddit, fromViewController: viewController)
            }
        }
    }
    
    // Show report options based on subreddit rules
    private func showReportRulesForThing(rules: [RDKRule], thingFullname: String, subreddit: String, fromViewController viewController: UIViewController) {
        let actions = rules.map { rule in
            Action(title: rule.short_name ?? rule.description ?? "Rule", icon: nil, style: .default) {
                // Report for this rule
                RDKClient.shared.createUserReportForThingWithFullname(thingFullname, subredditReason: rule.short_name ?? "") { error in
                    if let error = error {
                        Holla.showStatus("Failed to report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Reported", text: "Thanks for your report", duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                }
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
    
    // Show generic report options when no rules are available
    private func showGenericReportOptionsForThing(thingFullname: String, subreddit: String, fromViewController viewController: UIViewController) {
        let actions = [
            Action(title: "Spam", icon: nil, style: .default) {
                RDKClient.shared.createUserReportForThingWithFullname(thingFullname, siteReason: "spam") { error in
                    if let error = error {
                        Holla.showStatus("Failed to report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Reported as spam", text: nil, duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                }
            },
            Action(title: "Off-topic", icon: nil, style: .default) {
                RDKClient.shared.createUserReportForThingWithFullname(thingFullname, siteReason: "offtopic") { error in
                    if let error = error {
                        Holla.showStatus("Failed to report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Reported as off-topic", text: nil, duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                }
            },
            Action(title: "Other", icon: nil, style: .default) {
                // Show custom reason input
                let reportVC = ReportViewController(thingFullname: thingFullname, subreddit: subreddit)
                viewController.present(reportVC, animated: true)
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
}
