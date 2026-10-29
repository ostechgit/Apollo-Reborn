import UIKit
import AsyncDisplayKit

// CommentsHeaderSectionController - manages the comments header section
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CommentsHeaderSectionController: NSObject {
    
    private var post: RDKLink
    
    init(post: RDKLink) {
        self.post = post
        super.init()
    }
    
    func postTitle() -> String {
        return self.post.title ?? ""
    }
    
    func postAuthor() -> String {
        return self.post.author ?? ""
    }
    
    func postSubreddit() -> String {
        return self.post.subreddit ?? ""
    }
}
