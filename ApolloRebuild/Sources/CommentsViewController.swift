import UIKit
import AsyncDisplayKit

// CommentsViewController - a post and its comment thread
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Minimal for now: the post as a header, the tree flattened with indentation,
// and "more replies" rows that expand in place. The original adds collapsing,
// comment actions, sorting, the quick bar, search and media in comments.

class CommentsViewController: UIViewController, ASTableDataSource, ASTableDelegate {
    
    // A row in the flattened thread
    enum Row {
        case comment(RDKComment, depth: Int)
        case more(RDKMoreComments, depth: Int)
    }
    
    let tableNode = ASTableNode(style: .plain)
    private(set) var link: RDKLink
    private var rows: [Row] = []
    private var commentSort: RDKCommentSortingMethod = .default
    private var expandingMore = Set<String>()
    private let messageLabel = UILabel()
    
    init(link: RDKLink) {
        self.link = link
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = PostFormatting.abbreviatedCount(self.link.totalComments) + " Comments"
        self.view.backgroundColor = .systemBackground
        
        self.tableNode.dataSource = self
        self.tableNode.delegate = self
        self.tableNode.backgroundColor = .systemBackground
        self.view.addSubnode(self.tableNode)
        let tableView = self.tableNode.view
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        self.messageLabel.textColor = .secondaryLabel
        self.messageLabel.textAlignment = .center
        self.messageLabel.numberOfLines = 0
        self.messageLabel.text = "Loading comments\u{2026}"
        
        self.loadComments()
    }
    
    private func loadComments() {
        RDKClient.shared().linkAndComments(forLinkWithIdentifier: self.link.identifier ?? "", commentSort: self.commentSort, pagination: nil) { [weak self] link, comments, error in
            guard let self = self else { return }
            if let error = error {
                LogBuddy.error("CommentsViewController: thread failed (\((error as NSError).code))")
                self.messageLabel.text = "Couldn\u{2019}t load comments.\n\(error.localizedDescription)"
                self.tableNode.reloadSections(IndexSet(integer: 1), with: .none)
                return
            }
            if let link = link {
                // Fresher score/vote state than the feed's copy
                self.link = link
            }
            self.rows = CommentsViewController.flatten(comments ?? [], depth: 0)
            self.messageLabel.text = self.rows.isEmpty ? "No comments yet." : nil
            self.tableNode.reloadData()
        }
    }
    
    static func flatten(_ things: [RDKThing], depth: Int) -> [Row] {
        var rows: [Row] = []
        for thing in things {
            if let comment = thing as? RDKComment {
                rows.append(.comment(comment, depth: depth))
                rows.append(contentsOf: flatten(comment.replies ?? [], depth: depth + 1))
            } else if let more = thing as? RDKMoreComments {
                rows.append(.more(more, depth: depth))
            }
        }
        return rows
    }
    
    // MARK: - Expanding "more replies"
    
    private func expand(_ more: RDKMoreComments, at row: Int) {
        guard !more.isContinueThread, let key = more.fullName, !self.expandingMore.contains(key) else { return }
        self.expandingMore.insert(key)
        
        RDKClient.shared().moreComments(more, for: self.link, sort: self.commentSort) { [weak self] collection, error in
            guard let self = self else { return }
            self.expandingMore.remove(key)
            // The row may have moved if another expansion finished first
            guard let index = self.rows.firstIndex(where: { if case .more(let other, _) = $0 { return other === more } else { return false } }) else { return }
            guard error == nil else {
                LogBuddy.error("CommentsViewController: morechildren failed")
                return
            }
            // api/morechildren returns the comments flat, in thread order, each with its own depth
            let newRows: [Row] = (collection as? [RDKThing] ?? []).compactMap { thing in
                if let comment = thing as? RDKComment {
                    return .comment(comment, depth: comment.depth)
                } else if let nested = thing as? RDKMoreComments {
                    return .more(nested, depth: nested.depth)
                }
                return nil
            }
            self.rows.replaceSubrange(index...index, with: newRows)
            self.tableNode.performBatchUpdates({
                self.tableNode.deleteRows(at: [IndexPath(row: index, section: 1)], with: .fade)
                self.tableNode.insertRows(at: (index..<(index + newRows.count)).map { IndexPath(row: $0, section: 1) }, with: .fade)
            }, completion: nil)
        }
    }
    
    // MARK: - ASTableDataSource / ASTableDelegate
    
    func numberOfSections(in tableNode: ASTableNode) -> Int {
        return 2
    }
    
    func tableNode(_ tableNode: ASTableNode, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return self.rows.isEmpty ? 1 : self.rows.count
    }
    
    func tableNode(_ tableNode: ASTableNode, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        if indexPath.section == 0 {
            let link = self.link
            return { LargePostCellNode(link: link, isInsideComments: true) }
        }
        guard !self.rows.isEmpty else {
            let text = self.messageLabel.text ?? ""
            return { StatusMessageCellNode(text: text) }
        }
        let linkAuthor = self.link.author ?? ""
        switch self.rows[indexPath.row] {
        case .comment(let comment, let depth):
            return { CommentCellNode(comment: comment, depth: depth, linkAuthor: linkAuthor) }
        case .more(let more, let depth):
            return { MoreCommentsCellNode(more: more, depth: depth) }
        }
    }
    
    func tableNode(_ tableNode: ASTableNode, didSelectRowAt indexPath: IndexPath) {
        tableNode.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, indexPath.row < self.rows.count, case .more(let more, _) = self.rows[indexPath.row] else { return }
        self.expand(more, at: indexPath.row)
    }
}

// CommentCellNode - one comment, indented by depth with a colored thread line
class CommentCellNode: ASCellNode {
    
    let comment: RDKComment
    let depth: Int
    private let headerNode = ASTextNode()
    private let bodyNode = ASTextNode()
    private let threadLineNode = ASDisplayNode()
    private let separatorNode = ASDisplayNode()
    
    static let threadColors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple, .systemPink, .systemTeal]
    
    init(comment: RDKComment, depth: Int? = nil, linkAuthor: String? = nil) {
        self.comment = comment
        self.depth = depth ?? comment.depth
        super.init()
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        
        let author = comment.author ?? "[deleted]"
        let isOP = comment.isSubmitter || (linkAuthor != nil && author == linkAuthor)
        let authorColor: UIColor = comment.distinguished == "moderator" ? .systemGreen : (isOP ? .systemBlue : .label)
        let header = NSMutableAttributedString(string: author, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote).bold(),
            .foregroundColor: authorColor
        ])
        var details: [String] = []
        if isOP { details.append("OP") }
        details.append(comment.scoreHidden ? "\u{2013}" : PostFormatting.abbreviatedCount(comment.score))
        details.append(PostFormatting.relativeTime(since: comment.createdUTC) + (comment.edited != nil ? "*" : ""))
        let scoreColor: UIColor = comment.upvoted ? .systemOrange : (comment.downvoted ? .systemIndigo : .secondaryLabel)
        header.append(NSAttributedString(string: "  " + details.joined(separator: " \u{2022} "), attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: scoreColor
        ]))
        self.headerNode.attributedText = header
        
        self.bodyNode.attributedText = NSAttributedString(string: comment.body ?? "", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.label
        ])
        
        self.threadLineNode.backgroundColor = self.depth == 0 ? .clear : CommentCellNode.threadColors[(self.depth - 1) % CommentCellNode.threadColors.count]
        self.threadLineNode.style.width = ASDimensionMake(2)
        self.separatorNode.backgroundColor = .separator
        self.separatorNode.style.height = ASDimensionMake(0.5)
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let text = ASStackLayoutSpec(direction: .vertical, spacing: 4, justifyContent: .start, alignItems: .stretch, children: [self.headerNode, self.bodyNode])
        text.style.flexShrink = 1
        text.style.flexGrow = 1
        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 10, justifyContent: .start, alignItems: .stretch, children: [self.threadLineNode, text])
        let indent = CGFloat(max(self.depth - 1, 0)) * 12
        let inset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 10, left: 16 + indent, bottom: 10, right: 16), child: row)
        return ASStackLayoutSpec(direction: .vertical, spacing: 0, justifyContent: .start, alignItems: .stretch, children: [inset, self.separatorNode])
    }
}

// MoreCommentsCellNode - "N more replies" (or "Continue this thread")
class MoreCommentsCellNode: ASCellNode {
    
    private let textNode = ASTextNode()
    private let depth: Int
    
    init(more: RDKMoreComments, depth: Int) {
        self.depth = depth
        super.init()
        self.automaticallyManagesSubnodes = true
        let text = more.isContinueThread ? "Continue this thread on Reddit" : "\(more.count) more \(more.count == 1 ? "reply" : "replies")"
        self.textNode.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .footnote).bold(),
            .foregroundColor: more.isContinueThread ? UIColor.secondaryLabel : UIColor.systemBlue
        ])
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let indent = CGFloat(max(self.depth, 0)) * 12
        return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 10, left: 16 + indent, bottom: 10, right: 16), child: self.textNode)
    }
}

// StatusMessageCellNode - a single centered line of status text
class StatusMessageCellNode: ASCellNode {
    
    private let textNode = ASTextNode()
    
    init(text: String) {
        super.init()
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.textNode.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .subheadline),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: { let style = NSMutableParagraphStyle(); style.alignment = .center; return style }()
        ])
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24), child: self.textNode)
    }
}
