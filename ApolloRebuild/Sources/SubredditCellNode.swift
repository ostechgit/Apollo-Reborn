import AsyncDisplayKit

// SubredditCellNode - displays a single subreddit
class SubredditCellNode: ASCellNode {
    
    private let subreddit: RDKSubreddit
    private let label: ASTextNode
    
    init(subreddit: RDKSubreddit) {
        self.subreddit = subreddit
        self.label = ASTextNode()
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        self.label.attributedText = NSAttributedString(
            string: "r/" + (self.subreddit.display_name ?? ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        self.addSubnode(self.label)
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(
            insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16),
            child: self.label
        )
    }
}