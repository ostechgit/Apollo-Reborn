import UIKit
import AsyncDisplayKit

// PostCellNode - a post row for the secondary lists (profile, saved, search, multireddits)
// Not a class in the original; kept so those screens share LargePostCellNode's layout.

class PostCellNode: LargePostCellNode {
    
    init(post: RDKLink) {
        super.init(link: post)
    }
}
