import UIKit

// ActionController+UserReport - user reporting functionality
// Reconstructed from apollo-base 1.15.11 binary analysis.

extension ActionController {
    
    // Show user report options for a thing (post or comment)
    func normalUserReportSubredditRulesSelected(thingFullname: String,
                                               subreddit: String,
                                               tintAsModerator: Bool = false,
                                               fromViewController viewController: UIViewController) {
        
        // Show generic report options
        showGenericReportOptions(thingFullname: thingFullname, subreddit: subreddit, fromViewController: viewController)
    }
    
    // Show generic report options
    private func showGenericReportOptions(thingFullname: String, subreddit: String, fromViewController viewController: UIViewController) {
        let spamAction = Action(title: "Spam", icon: nil, style: .default) { _ in
            RDKClient.shared.createUserReportForThingWithFullname(thingFullname, siteReason: "spam") { error in
                if let error = error {
                    Holla.showStatus("Failed to report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Reported as spam", text: nil, duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let offTopicAction = Action(title: "Off-topic", icon: nil, style: .default) { _ in
            RDKClient.shared.createUserReportForThingWithFullname(thingFullname, siteReason: "offtopic") { error in
                if let error = error {
                    Holla.showStatus("Failed to report", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Reported as off-topic", text: nil, duration: 2.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let otherAction = Action(title: "Other", icon: nil, style: .default) { _ in
            let reportVC = UserReportViewController(thingFullname: thingFullname, subreddit: subreddit)
            viewController.present(reportVC, animated: true)
        }
        
        showActionSheet(actions: [spamAction, offTopicAction, otherAction], fromViewController: viewController)
    }
}
