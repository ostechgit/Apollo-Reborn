import UIKit
import AsyncDisplayKit

// ActionController+Moderator - moderator actions for posts and comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

extension ActionController {
    
    // Show moderator actions for a comment
    func showModeratorActions(forComment comment: RDKComment,
                             sectionController: ASSectionController,
                             viewController: UIViewController,
                             completion: ((Action) -> Void)? = nil) {
        
        let approveAction = Action(title: "Approve", icon: "option-approve", style: .default) { _ in
            RDKClient.shared().approve(comment) { error in
                if let error = error {
                    Holla.showStatus("Failed to approve comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Approved", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let removeAction = Action(title: "Remove", icon: "option-trash", style: .destructive) { _ in
            RDKClient.shared().remove(comment, spam: false) { error in
                if let error = error {
                    Holla.showStatus("Failed to remove comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Removed", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let spamAction = Action(title: "Mark Spam", icon: "option-spam", style: .destructive) { _ in
            RDKClient.shared().remove(comment, spam: true) { error in
                if let error = error {
                    Holla.showStatus("Failed to mark as spam", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Marked as spam", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let stickyAction = Action(title: "Sticky", icon: "option-sticky", style: .default) { _ in
            RDKClient.shared().distinguishComment(comment, status: 1, sticky: true) { error in
                if let error = error {
                    Holla.showStatus("Failed to sticky comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Sticky", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let lockAction = Action(title: "Lock", icon: "option-lock", style: .default) { _ in
            RDKClient.shared().lock(comment) { error in
                if let error = error {
                    Holla.showStatus("Failed to lock comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Locked", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let distinguishAction = Action(title: "Distinguish", icon: "option-moderator", style: .default) { _ in
            RDKClient.shared().distinguishComment(comment, status: 1, sticky: false) { error in
                if let error = error {
                    Holla.showStatus("Failed to distinguish comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Distinguished", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let banAction = Action(title: "Ban User", icon: "option-ban", style: .destructive) { _ in
            let banVC = BanUserViewController(username: comment.author ?? "", subreddit: comment.subreddit ?? "")
            viewController.present(banVC, animated: true)
        }
        
        let reportsAction = Action(title: "View Reports", icon: "option-report", style: .default) { _ in
            let reportsVC = CommentReportsViewController(comment: comment)
            viewController.present(reportsVC, animated: true)
        }
        
        showActionSheet(actions: [approveAction, removeAction, spamAction, stickyAction, lockAction, distinguishAction, banAction, reportsAction], fromViewController: viewController)
    }
    
    // Show moderator actions for a post
    func showModeratorActions(link: RDKLink,
                             sectionController: ASSectionController,
                             viewController: UIViewController,
                             completion: ((Action) -> Void)? = nil) {
        
        let approveAction = Action(title: "Approve", icon: "option-approve", style: .default) { _ in
            RDKClient.shared().approve(link) { error in
                if let error = error {
                    Holla.showStatus("Failed to approve post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Approved", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let removeAction = Action(title: "Remove", icon: "option-trash", style: .destructive) { _ in
            RDKClient.shared().remove(link, spam: false) { error in
                if let error = error {
                    Holla.showStatus("Failed to remove post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Removed", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let spamAction = Action(title: "Mark Spam", icon: "option-spam", style: .destructive) { _ in
            RDKClient.shared().remove(link, spam: true) { error in
                if let error = error {
                    Holla.showStatus("Failed to mark as spam", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Marked as spam", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let stickyAction = Action(title: "Sticky", icon: "option-sticky", style: .default) { _ in
            RDKClient.shared().distinguishThing(withFullName:link.fullName ?? "", status: 1) { error in
                if let error = error {
                    Holla.showStatus("Failed to sticky post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Sticky", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let lockAction = Action(title: "Lock", icon: "option-lock", style: .default) { _ in
            RDKClient.shared().lockLink(withFullname: link.fullName ?? "") { error in
                if let error = error {
                    Holla.showStatus("Failed to lock post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Locked", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let sortAction = Action(title: "Set Suggested Sort", icon: "option-set-suggested-sort", style: .default) { _ in
            let sortVC = SuggestedSortViewController(link: link)
            viewController.present(sortVC, animated: true)
        }
        
        let contestAction = Action(title: "Enable Contest Mode", icon: "option-contest-mode", style: .default) { _ in
            RDKClient.shared().setContestModeForLinkWithFullname(link.fullName ?? "", contestMode: true) { error in
                if let error = error {
                    Holla.showStatus("Failed to enable contest mode", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                } else {
                    Holla.showStatus("Contest mode enabled", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                }
            }
        }
        
        let banAction = Action(title: "Ban User", icon: "option-ban", style: .destructive) { _ in
            let banVC = BanUserViewController(username: link.author ?? "", subreddit: link.subreddit ?? "")
            viewController.present(banVC, animated: true)
        }
        
        let reportsAction = Action(title: "View Reports", icon: "option-report", style: .default) { _ in
            let reportsVC = LinkReportsViewController(link: link)
            viewController.present(reportsVC, animated: true)
        }
        
        let flairAction = Action(title: "Edit Flair", icon: "option-set-flair", style: .default) { _ in
            let flairVC = FlairSelectorViewController(link: link)
            viewController.present(flairVC, animated: true)
        }
        
        showActionSheet(actions: [approveAction, removeAction, spamAction, stickyAction, lockAction, sortAction, contestAction, banAction, reportsAction, flairAction], fromViewController: viewController)
    }
}
