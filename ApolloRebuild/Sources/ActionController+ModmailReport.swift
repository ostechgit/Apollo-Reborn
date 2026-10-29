import UIKit

// ActionController+ModmailReport - modmail reporting functionality
// Reconstructed from apollo-base 1.15.11 binary analysis.

extension ActionController {
    
    // Show modmail report options for a thing (post or comment)
    func modmailReportSubredditRulesSelected(thingFullname: String,
                                            subreddit: String,
                                            tintAsModerator: Bool = false,
                                            fromViewController viewController: UIViewController) {
        
        let reportAction = Action(title: "Report to Mods", icon: nil, style: .default) { _ in
            let reportVC = ModmailReportViewController(thingFullname: thingFullname, subreddit: subreddit)
            viewController.present(reportVC, animated: true)
        }
        
        showActionSheet(actions: [reportAction], fromViewController: viewController)
    }
}
