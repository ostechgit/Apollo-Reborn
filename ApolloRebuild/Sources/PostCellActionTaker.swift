import Foundation

// PostCellActionTaker - handles actions on post cells (upvote, downvote, save, etc.)
// Reconstructed from apollo-base 1.15.11 binary analysis.

class PostCellActionTaker {
    
    static let shared = PostCellActionTaker()
    
    private init() {}
    
    func upvotePost(_ post: RDKLink, completion: @escaping (Bool) -> Void) {
        // Upvote the post on Reddit
        RDKClient.shared.voteOnLink(post, direction: .up) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func downvotePost(_ post: RDKLink, completion: @escaping (Bool) -> Void) {
        // Downvote the post on Reddit
        RDKClient.shared.voteOnLink(post, direction: .down) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func savePost(_ post: RDKLink, completion: @escaping (Bool) -> Void) {
        // Save the post
        RDKClient.shared.saveLink(post) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
    
    func hidePost(_ post: RDKLink, completion: @escaping (Bool) -> Void) {
        // Hide the post (mark as read)
        RDKClient.shared.hideLink(post) { error in
            DispatchQueue.main.async {
                completion(error == nil)
            }
        }
    }
}
