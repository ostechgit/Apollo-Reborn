import UIKit
import AsyncDisplayKit

// CrosspostNode - displays a crosspost
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CrosspostNode: ASCellNode {
    
    private let post: RDKLink
    
    init(post: RDKLink) {
        self.post = post
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let title = ASTextNode()
        title.attributedText = NSAttributedString(
            string: self.post.title ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        let source = ASTextNode()
        source.attributedText = NSAttributedString(
            string: "Crossposted from r/" + (self.post.subreddit ?? ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        self.addSubnode(title)
        self.addSubnode(source)
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        source.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    
    override func layout() {
        super.layout()
        guard let nodes = self.subnodes, nodes.count >= 2 else { return }
        let title = nodes[0]
        let source = nodes[1]
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        source.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
}
