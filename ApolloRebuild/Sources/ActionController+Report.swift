import UIKit

// ActionController+Report - general post/comment reporting
// Reconstructed from apollo-base 1.15.11 binary analysis.

extension ActionController {
    
    // Show general report options for a thing (post or comment)
    func reportSubredditRulesSelected(thingFullname: String,
                                     subreddit: String,
                                     tintAsModerator: Bool = false,
                                     fromViewController viewController: UIViewController) {
        
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
            let reportVC = ReportViewController(thingFullname: thingFullname, subreddit: subreddit)
            viewController.present(reportVC, animated: true)
        }
        
        showActionSheet(actions: [spamAction, offTopicAction, otherAction], fromViewController: viewController)
    }
}
