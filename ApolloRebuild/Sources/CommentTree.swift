import Foundation

// CommentTree - represents a threaded comment tree
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CommentTree {
    
    private var rootComments: [RDKComment] = []
    
    init(comments: [RDKComment]) {
        self.rootComments = comments
    }
    
    func rootCommentCount() -> Int {
        return self.rootComments.count
    }
    
    func rootComment(at index: Int) -> RDKComment? {
        if index < self.rootComments.count {
            return self.rootComments[index]
        }
        return nil
    }
}
