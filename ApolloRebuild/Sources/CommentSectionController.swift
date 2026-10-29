import UIKit
import AsyncDisplayKit

// CommentSectionController - manages a section of comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CommentSectionController: NSObject {
    
    private var comments: [RDKComment] = []
    
    init(comments: [RDKComment]) {
        self.comments = comments
        super.init()
    }
    
    func commentCount() -> Int {
        return self.comments.count
    }
    
    func comment(at index: Int) -> RDKComment? {
        if index < self.comments.count {
            return self.comments[index]
        }
        return nil
    }
}
