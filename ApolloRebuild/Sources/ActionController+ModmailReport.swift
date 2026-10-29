import UIKit

// ActionController+ModmailReport - modmail reporting functionality
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original function signatures recovered from RE:
// - modmailReportSubredditRulesSelected(thingFullname:subreddit:tintAsModerator:fromViewController:)

extension ActionController {
    
    // Show modmail report options for a thing (post or comment)
    func modmailReportSubredditRulesSelected(thingFullname: String,
                                            subreddit: String,
                                            tintAsModerator: Bool = false,
                                            fromViewController viewController: UIViewController) {
        
        // Fetch subreddit rules to show as report options
        RDKClient.shared.subredditWithName(subreddit) { [weak self] subredditObj, error in
            if let subredditObj = subredditObj, let rules = subredditObj.rules {
                // Show rules as report options
                self?.showModmailReportRules(rules: rules, thingFullname: thingFullname, subreddit: subreddit, fromViewController: viewController)
            } else {
                // No rules, show generic report options
                self?.showGenericModmailReportOptions(thingFullname: thingFullname, subreddit: subreddit, fromViewController: viewController)
            }
        }
    }
    
    // Show modmail report options based on subreddit rules
    private func showModmailReportRules(rules: [RDKRule], thingFullname: String, subreddit: String, fromViewController viewController: UIViewController) {
        let actions = rules.map { rule in
            Action(title: rule.short_name ?? rule.description ?? "Rule", icon: nil, style: .default) {
                // Send modmail report for this rule
                let message = "Report for \(thingFullname): \(rule.short_name ?? "Rule violation")"
                RDKClient.shared.createModmailThread(subreddit: subreddit, subject: "Report", message: message) { error in
                    if let error = error {
                        Holla.showStatus("Failed to send report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Report sent", text: "Mods have been notified", duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                }
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
    
    // Show generic modmail report options when no rules are available
    private func showGenericModmailReportOptions(thingFullname: String, subreddit: String, fromViewController viewController: UIViewController) {
        let actions = [
            Action(title: "Report to Mods", icon: nil, style: .default) {
                // Show custom reason input
                let reportVC = ModmailReportViewController(thingFullname: thingFullname, subreddit: subreddit)
                viewController.present(reportVC, animated: true)
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
}
