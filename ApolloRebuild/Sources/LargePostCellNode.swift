import UIKit
import AsyncDisplayKit

// PostCellActionDelegate - what a post cell asks its screen to do
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.PostCellActionDelegate).
protocol PostCellActionDelegate: AnyObject {
    func postCell(_ cell: LargePostCellNode, didTapVote direction: RDKVoteDirection, on link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapSaveOn link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapMediaOf link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapMoreOptionsOn link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapSubreddit named: String)
    func postCell(_ cell: LargePostCellNode, didTapAuthor named: String)
}

// LargePostOptionButtonsNode - the ⋯ ↑ ↓ cluster on the right of the info rows
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Measured: three 32x32 boxes with 2pt between them, right edge 16pt in. The
// vote buttons draw a bare grey arrow until the post is voted on, then a filled
// rounded square in the vote's brand colour with a white arrow.
class LargePostOptionButtonsNode: ASDisplayNode {

    let link: RDKLink
    let upvoteButton = ASButtonNode()
    let downvoteButton = ASButtonNode()
    let moreOptionsButton = ASButtonNode()

    var onVote: ((RDKVoteDirection) -> Void)?
    var onMoreOptions: (() -> Void)?

    init(link: RDKLink) {
        self.link = link
        super.init()
        self.automaticallyManagesSubnodes = true

        for button in [self.upvoteButton, self.downvoteButton, self.moreOptionsButton] {
            button.style.preferredSize = CGSize(width: 32, height: 32)
        }
        self.moreOptionsButton.setImage(ApolloAssets.image(named: "inline-more-options"), for: .normal)
        self.moreOptionsButton.imageNode.contentMode = .center
        self.moreOptionsButton.accessibilityLabel = "More Options"
        self.moreOptionsButton.addTarget(self, action: #selector(moreOptionsTapped), forControlEvents: .touchUpInside)

        self.upvoteButton.accessibilityLabel = "Upvote"
        self.downvoteButton.accessibilityLabel = "Downvote"
        self.upvoteButton.addTarget(self, action: #selector(upvoteTapped), forControlEvents: .touchUpInside)
        self.downvoteButton.addTarget(self, action: #selector(downvoteTapped), forControlEvents: .touchUpInside)

        self.update()
    }

    func update() {
        let traits = self.apolloDrawingTraits
        self.upvoteButton.setImage(ApolloArtwork.voteButton(up: true, voted: self.link.upvoted, traits: traits), for: .normal)
        self.downvoteButton.setImage(ApolloArtwork.voteButton(up: false, voted: self.link.downvoted, traits: traits), for: .normal)
        self.moreOptionsButton.imageNode.image = ApolloAssets.image(named: "inline-more-options")?
            .withTintColor(ApolloPalette.iconGrey, renderingMode: .alwaysOriginal)

        // Archived posts can't be voted on
        for button in [self.upvoteButton, self.downvoteButton] {
            button.isEnabled = !self.link.isArchived
            button.alpha = self.link.isArchived ? 0.4 : 1
        }
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASStackLayoutSpec(direction: .horizontal, spacing: 2,
                                 justifyContent: .end, alignItems: .center,
                                 children: [self.moreOptionsButton, self.upvoteButton, self.downvoteButton])
    }

    @objc private func upvoteTapped() {
        self.onVote?(self.link.upvoted ? .none : .up)
    }

    @objc private func downvoteTapped() {
        self.onVote?(self.link.downvoted ? .none : .down)
    }

    @objc private func moreOptionsTapped() {
        self.onMoreOptions?()
    }
}

// LargePostCellNode - a post in the feed.
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Subnode names follow the original (titleNode, postInfoNode, richMediaNode,
// optionButtonsNode). Measured from the original at 3x:
//
//   * 16pt side insets, 16pt above the title, 12pt below the info rows
//   * title 17pt regular, black, unlimited lines, flair chip inline
//   * self text 15pt regular #666666, 3 lines, ellipsised
//   * media either edge to edge (Reddit-hosted) or a 16pt-inset card (external)
//   * info row 1 at 14pt, row 2 at 13pt, 8pt between them
//   * ⋯ ↑ ↓ are three 32x32 boxes sitting on the right, vertically centred
//   * an 8pt full-bleed systemGray6 band separates one cell from the next
//
// The original also draws crossposts, awards, moderator banners, the read
// indicator, the saved triangle and inline video; those are still to come.
//
// The read (visited) state dims the title and the info rows but never the media.

class LargePostCellNode: ASCellNode, ASTextNodeDelegate {

    var onLinkTapped: ((URL) -> Void)?
    /// Poll options are not votable through the API: stock opens the Reddit
    /// mobile site and refreshes the results when the reader comes back.
    var onPollTapped: (() -> Void)?

    func textNode(_ textNode: ASTextNode, tappedLinkAttribute attribute: String,
                  value: Any, at point: CGPoint, textRange: NSRange) {
        if let url = value as? URL {
            self.onLinkTapped?(url)
        } else if let string = value as? String, let url = URL(string: string) {
            self.onLinkTapped?(url)
        }
    }

    var link: RDKLink
    let inSpecificSubreddit: Bool
    // The comments header shows the whole self text; the feed shows an excerpt
    let isInsideComments: Bool
    weak var actionDelegate: PostCellActionDelegate?

    let titleNode = ASTextNode()
    let postInfoNode: PostInfoNode
    let selfTextNode = ASTextNode()
    /// Poll options with their share of the vote, drawn under the self text the
    /// way the original shows a poll.
    private var pollNodes: [ASButtonNode] = []
    let richMediaNode: RichMediaNode?
    /// A crosspost draws its PARENT's media inside a CrosspostNode card instead
    /// of a plain RichMediaNode; the cell still owns the media tap.
    let crosspostNode: CrosspostNode?
    let optionButtonsNode: LargePostOptionButtonsNode
    /// The comments header's row of large actions (vote, save, reply, share).
    var quickBarNode: CommentsQuickBarNode?
    /// Reply and share aren't in PostCellActionDelegate; the comments screen
    /// wires them here.
    var onReplyTapped: (() -> Void)?
    var onShareTapped: (() -> Void)?

    private let quickBarSeparatorNode = ASDisplayNode()
    private let commentsSeparatorNode = ASDisplayNode()
    private let commentsGapNode = ASDisplayNode()

    private let separatorNode = ASDisplayNode()

    init(link: RDKLink, inSpecificSubreddit: Bool = false, isInsideComments: Bool = false) {
        self.link = link
        self.inSpecificSubreddit = inSpecificSubreddit
        self.isInsideComments = isInsideComments
        self.postInfoNode = PostInfoNode(link: link, showsSubreddit: !inSpecificSubreddit,
                                         isCompact: false, isInsideComments: isInsideComments)
        if let parent = link.crosspostParent {
            self.crosspostNode = CrosspostNode(crosspostParent: parent)
            self.richMediaNode = nil
        } else {
            self.crosspostNode = nil
            self.richMediaNode = RichMediaNode(link: link, isShownInCommentsHeader: isInsideComments)
        }
        self.optionButtonsNode = LargePostOptionButtonsNode(link: link)
        super.init()

        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.backgroundColor = .systemBackground

        self.titleNode.maximumNumberOfLines = 0
        if isInsideComments {
            self.selfTextNode.delegate = self
            self.selfTextNode.linkAttributeNames = [NSAttributedString.Key.link.rawValue]
            self.selfTextNode.isUserInteractionEnabled = true
        }
        self.pollNodes = (link.pollOptions ?? []).map { option in
            let node = ASButtonNode()
            let text = option["text"] as? String ?? ""
            let votes = (option["vote_count"] as? NSNumber)?.intValue ?? 0
            let total = max(link.pollTotalVotes, 1)
            let share = Int((Double(votes) / Double(total) * 100).rounded())
            node.setAttributedTitle(NSAttributedString(string: "\(text)   \(share)%", attributes: [
                .font: UIFont.systemFont(ofSize: 15),
                .foregroundColor: UIColor.label,
            ]), for: .normal)
            node.addTarget(self, action: #selector(LargePostCellNode.pollTapped), forControlEvents: .touchUpInside)
            return node
        }
        self.selfTextNode.maximumNumberOfLines = isInsideComments ? 0 : 3
        self.selfTextNode.truncationMode = .byTruncatingTail

        self.separatorNode.backgroundColor = ApolloPalette.cellSeparator
        self.separatorNode.style.height = ASDimensionMake(8)

        // The comments header replaces the feed's 8pt cell band with the two
        // hairlines the original draws around its quick bar: one inset 16pt
        // above it, one full bleed below it, then the comments list begins.
        self.quickBarSeparatorNode.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.quickBarSeparatorNode.style.height = ASDimensionMake(0.5)
        self.commentsSeparatorNode.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.commentsSeparatorNode.style.height = ASDimensionMake(0.5)
        self.commentsGapNode.backgroundColor = .systemGroupedBackground
        self.commentsGapNode.style.height = ASDimensionMake(10)

        if isInsideComments {
            let quickBar = CommentsQuickBarNode(voteStatus: link.voteStatus, isSaved: link.saved)
            quickBar.onUpvote = { [weak self] in
                guard let self = self else { return }
                self.actionDelegate?.postCell(self, didTapVote: .up, on: self.link)
            }
            quickBar.onDownvote = { [weak self] in
                guard let self = self else { return }
                self.actionDelegate?.postCell(self, didTapVote: .down, on: self.link)
            }
            quickBar.onSave = { [weak self] in
                guard let self = self else { return }
                self.actionDelegate?.postCell(self, didTapSaveOn: self.link)
            }
            quickBar.onReply = { [weak self] in self?.onReplyTapped?() }
            quickBar.onShare = { [weak self] in self?.onShareTapped?() }
            self.quickBarNode = quickBar
        }

        self.postInfoNode.isRead = link.visited
        self.postInfoNode.onSubredditTapped = { [weak self] name in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapSubreddit: name)
        }
        self.postInfoNode.onAuthorTapped = { [weak self] name in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapAuthor: name)
        }

        self.optionButtonsNode.onVote = { [weak self] direction in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapVote: direction, on: self.link)
        }
        self.optionButtonsNode.onMoreOptions = { [weak self] in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapMoreOptionsOn: self.link)
        }

        self.richMediaNode?.onTapped = { [weak self] in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapMediaOf: self.link)
        }

        self.crosspostNode?.onTapped = { [weak self] in
            guard let self = self else { return }
            self.actionDelegate?.postCell(self, didTapMediaOf: self.link)
        }

        self.updateContent()
    }

    // MARK: - Content

    private func updateContent() {
        self.isRead = self.link.visited
        self.titleNode.attributedText = PostTitleNode.attributedTitle(for: self.link,
                                                                     read: self.link.visited,
                                                                     traitCollection: self.apolloDrawingTraits)

        if self.link.selfPost, let selfText = self.link.selfText, !selfText.isEmpty {
            // Reddit's selftext is markdown. The comments header draws the
            // whole body in the label colour; the feed shows an excerpt in the
            // dimmed grey the info row uses.
            var style = self.isInsideComments ? MarkdownText.Style.postBody : MarkdownText.Style.comment
            if !self.isInsideComments {
                style.textColor = self.link.visited ? ApolloPalette.readSecondaryText : ApolloPalette.secondaryText
            }
            self.selfTextNode.attributedText = MarkdownText.attributedString(selfText, style: style)
        }
        self.postInfoNode.update()
    }

    private var isRead: Bool = false

    /// Call after changing the link's vote state so the info rows and the
    /// buttons redraw.
    func updateActionState() {
        self.postInfoNode.update()
        self.optionButtonsNode.update()
    }

    @objc private func pollTapped() {
        self.onPollTapped?()
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let horizontalInset: CGFloat = 16
        let textInsets = UIEdgeInsets(top: 16, left: horizontalInset, bottom: 0, right: horizontalInset)

        var children: [ASLayoutElement] = []
        // Title (and the self-text excerpt) sit inside the cell's side insets.
        var headingChildren: [ASLayoutElement] = [self.titleNode]
        if self.selfTextNode.attributedText != nil {
            self.selfTextNode.style.spacingBefore = 10
            headingChildren.append(self.selfTextNode)
        }
        // A poll's options follow the body text.
        for (index, pollNode) in self.pollNodes.enumerated() {
            pollNode.style.spacingBefore = index == 0 ? 12 : 8
            headingChildren.append(pollNode)
        }
        let heading = ASInsetLayoutSpec(insets: textInsets,
                                        child: ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                                                 justifyContent: .start, alignItems: .stretch,
                                                                 children: headingChildren))
        children.append(heading)

        // Media is full width (it insets itself when it draws a link card).
        if let crosspost = self.crosspostNode {
            // Measured: the crosspost card is inset 16pt on all sides, 16pt
            // under the title, and its footer sits 12pt above the info rows.
            children.append(ASInsetLayoutSpec(insets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16),
                                              child: crosspost))
        } else if let media = self.richMediaNode {
            children.append(media)
        }

        // The feed has a ⋯/vote cluster; the original detail header instead
        // owns CommentsQuickBarNode (Headers/Swift/CommentsHeaderCellNode.swift).
        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1
        var infoChildren: [ASLayoutElement] = [self.postInfoNode, spacer]
        if !self.isInsideComments { infoChildren.append(self.optionButtonsNode) }
        let infoRow = ASStackLayoutSpec(direction: .horizontal, spacing: 8,
                                        justifyContent: .start, alignItems: .center,
                                        children: infoChildren)
        self.postInfoNode.style.flexShrink = 1

        let info = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: horizontalInset, bottom: 12, right: horizontalInset),
                                     child: infoRow)
        // Measured: 20pt under an edge-to-edge picture, 12.5pt under a link card
        // and 12pt under a crosspost card (both cards draw their own padding).
        if self.crosspostNode != nil {
            info.style.spacingBefore = 12
        } else if self.richMediaNode?.presentation == .fullBleed {
            info.style.spacingBefore = 20
        } else {
            info.style.spacingBefore = 12.5
        }
        children.append(info)

        if let quickBar = self.quickBarNode {
            // Measured off the original: hairline inset 16pt, a 49pt action row,
            // a full-bleed hairline, then the comments list's grey background.
            let insetSeparator = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset),
                                                   child: self.quickBarSeparatorNode)
            insetSeparator.style.spacingBefore = 0
            children.append(insetSeparator)
            quickBar.style.height = ASDimensionMake(49)
            children.append(quickBar)
            children.append(self.commentsSeparatorNode)
            children.append(self.commentsGapNode)
        }

        let content = ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                        justifyContent: .start, alignItems: .stretch,
                                        children: children)
        let tail: [ASLayoutElement] = self.quickBarNode == nil ? [content, self.separatorNode] : [content]
        return ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                 justifyContent: .start, alignItems: .stretch,
                                 children: tail)
    }
}

// PostTitleNode - a post's title, with any link flair chip inline at the end
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.PostTitleNode).
//
// The flair chip is not a separate node in the original: it flows with the
// title's last line and wraps to the next line when there is no room, which is
// what an inline text attachment gives us for free.
enum PostTitleNode {

    static func attributedTitle(for link: RDKLink, read: Bool, traitCollection: UITraitCollection) -> NSAttributedString {
        let title = NSMutableAttributedString(string: link.title ?? "", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .foregroundColor: read ? ApolloPalette.readTitle : UIColor.label
        ])

        if let flair = PostFormatting.flairText(for: link),
           let chip = ApolloArtwork.flairChip(text: flair, traits: traitCollection) {
            let attachment = NSTextAttachment(image: chip)
            // Sit the chip on the text baseline: its bottom lands just under
            // the descender so it reads as part of the line rather than above it.
            attachment.bounds = CGRect(x: 4, y: -6, width: chip.size.width, height: chip.size.height)
            title.append(NSAttributedString(attachment: attachment))
        }
        return title
    }
}
