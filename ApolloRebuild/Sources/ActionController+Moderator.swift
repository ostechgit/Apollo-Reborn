import UIKit
import AsyncDisplayKit

// ActionController+Moderator - moderator actions for posts and comments
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original function signatures recovered from RE:
// - showModeratorActions(forComment:sectionController:viewController:completion:)
// - showModeratorActions(link:sectionController:viewController:completion:)
//
// Moderator action kinds (from apollo-reborn's action menu layout):
// mod-approve, mod-remove, mod-spam, mod-oc, mod-sticky, mod-lock,
// mod-ignore-reports, mod-view-reports, mod-distinguish, mod-suggested-sort,
// mod-contest-mode, mod-ban-user, mod-nuke, mod-compliment, mod-mail,
// mod-queue, mod-log, mod-reports, mod-spam-queue, mod-unmoderated,
// mod-edited, mod-all-comments, mod-traffic, mod-ban-users, mod-mute-users,
// mod-edit-flair, mod-removal-reasons, mod-rules, mod-automoderator,
// mod-approved-submitters, mod-moderators

extension ActionController {
    
    // Show moderator actions for a comment
    func showModeratorActions(forComment comment: RDKComment,
                             sectionController: ASSectionController,
                             viewController: UIViewController,
                             completion: ((Action) -> Void)? = nil) {
        
        let actions = [
            Action(title: "Approve", icon: "option-approve", style: .default) {
                // Approve the comment
                RDKClient.shared.approveComment(comment) { error in
                    if let error = error {
                        Holla.showStatus("Failed to approve comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Approved", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Remove", icon: "option-trash", style: .destructive) {
                // Remove the comment
                RDKClient.shared.removeComment(comment, spam: false) { error in
                    if let error = error {
                        Holla.showStatus("Failed to remove comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Removed", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Mark Spam", icon: "option-spam", style: .destructive) {
                // Mark as spam
                RDKClient.shared.removeComment(comment, spam: true) { error in
                    if let error = error {
                        Holla.showStatus("Failed to mark as spam", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Marked as spam", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Sticky", icon: "option-sticky", style: .default) {
                // Distinguish/sticky the comment
                RDKClient.shared.distinguishComment(comment, status: 1, sticky: true) { error in
                    if let error = error {
                        Holla.showStatus("Failed to sticky comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Sticky", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Lock", icon: "option-lock", style: .default) {
                // Lock the comment
                RDKClient.shared.lockComment(comment) { error in
                    if let error = error {
                        Holla.showStatus("Failed to lock comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Locked", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Distinguish", icon: "option-moderator", style: .default) {
                // Distinguish the comment
                RDKClient.shared.distinguishComment(comment, status: 1, sticky: false) { error in
                    if let error = error {
                        Holla.showStatus("Failed to distinguish comment", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Distinguished", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Ban User", icon: "option-ban", style: .destructive) {
                // Ban the user from the subreddit
                let banVC = BanUserViewController(username: comment.author, subreddit: comment.subreddit)
                viewController.present(banVC, animated: true)
                completion?($0)
            },
            Action(title: "View Reports", icon: "option-report", style: .default) {
                // View reports for this comment
                let reportsVC = CommentReportsViewController(comment: comment)
                viewController.present(reportsVC, animated: true)
                completion?($0)
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
    
    // Show moderator actions for a post
    func showModeratorActions(link: RDKLink,
                             sectionController: ASSectionController,
                             viewController: UIViewController,
                             completion: ((Action) -> Void)? = nil) {
        
        let actions = [
            Action(title: "Approve", icon: "option-approve", style: .default) {
                // Approve the post
                RDKClient.shared.approveLink(link) { error in
                    if let error = error {
                        Holla.showStatus("Failed to approve post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Approved", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Remove", icon: "option-trash", style: .destructive) {
                // Remove the post
                RDKClient.shared.removeLink(link, spam: false) { error in
                    if let error = error {
                        Holla.showStatus("Failed to remove post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Removed", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Mark Spam", icon: "option-spam", style: .destructive) {
                // Mark as spam
                RDKClient.shared.removeLink(link, spam: true) { error in
                    if let error = error {
                        Holla.showStatus("Failed to mark as spam", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Marked as spam", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Sticky", icon: "option-sticky", style: .default) {
                // Sticky the post (set as distinguished)
                RDKClient.shared.distinguishThingWithFullName(link.fullname, status: 1) { error in
                    if let error = error {
                        Holla.showStatus("Failed to sticky post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Sticky", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Lock", icon: "option-lock", style: .default) {
                // Lock the post
                RDKClient.shared.lockLinkWithFullname(link.fullname) { error in
                    if let error = error {
                        Holla.showStatus("Failed to lock post", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Locked", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Set Suggested Sort", icon: "option-set-suggested-sort", style: .default) {
                // Set suggested sort for the post
                let sortVC = SuggestedSortViewController(link: link)
                viewController.present(sortVC, animated: true)
                completion?($0)
            },
            Action(title: "Enable Contest Mode", icon: "option-contest-mode", style: .default) {
                // Enable contest mode
                RDKClient.shared.setContestModeForLinkWithFullname(link.fullname, contestMode: true) { error in
                    if let error = error {
                        Holla.showStatus("Failed to enable contest mode", text: error.localizedDescription, duration: 3.0, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    } else {
                        Holla.showStatus("Contest mode enabled", text: nil, duration: 1.5, savedItemFullName: nil, fromViewController: viewController, tappedBlock: nil)
                    }
                    completion?($0)
                }
            },
            Action(title: "Ban User", icon: "option-ban", style: .destructive) {
                // Ban the user from the subreddit
                let banVC = BanUserViewController(username: link.author, subreddit: link.subreddit)
                viewController.present(banVC, animated: true)
                completion?($0)
            },
            Action(title: "View Reports", icon: "option-report", style: .default) {
                // View reports for this post
                let reportsVC = LinkReportsViewController(link: link)
                viewController.present(reportsVC, animated: true)
                completion?($0)
            },
            Action(title: "Edit Flair", icon: "option-set-flair", style: .default) {
                // Edit flair for the post
                let flairVC = FlairSelectorViewController(link: link)
                viewController.present(flairVC, animated: true)
                completion?($0)
            }
        ]
        
        showActionSheet(actions: actions, fromViewController: viewController)
    }
}
