import UIKit
import AsyncDisplayKit

// CommentsQuickBarNode - the row of large action buttons under the post on a
// comments screen.
// Reconstructed from apollo-base 1.15.11 binary analysis
// (Apollo.CommentsQuickBarNode) and measured off 3x screenshots of the original.
//
// The original's fields are upvoteButton, downvoteButton, an optional
// saveButton, replyButton, shareButton and an optional editButton (present on
// your own post). Measured on a post that isn't yours:
//
//   * five buttons, glyphs ~28pt tall, evenly distributed across the full width
//   * all drawn in the accent colour, except a cast vote, which fills in that
//     vote's brand colour
//   * each button is a full-height 44pt target with no visible background
//
// The edit button (your own posts) is not wired up yet.

class CommentsQuickBarNode: ASDisplayNode {

    var onUpvote: (() -> Void)?
    var onDownvote: (() -> Void)?
    var onSave: (() -> Void)?
    var onReply: (() -> Void)?
    var onShare: (() -> Void)?

    private let upvoteNode = ASButtonNode()
    private let downvoteNode = ASButtonNode()
    private let saveNode = ASButtonNode()
    private let replyNode = ASButtonNode()
    private let shareNode = ASButtonNode()

    private var voteStatus: RDKVoteStatus
    private let isSaved: Bool

    init(voteStatus: RDKVoteStatus, isSaved: Bool) {
        self.voteStatus = voteStatus
        self.isSaved = isSaved
        super.init()
        self.automaticallyManagesSubnodes = true
        self.backgroundColor = .systemBackground

        self.upvoteNode.addTarget(self, action: #selector(upvoteTapped), forControlEvents: .touchUpInside)
        self.downvoteNode.addTarget(self, action: #selector(downvoteTapped), forControlEvents: .touchUpInside)
        self.saveNode.addTarget(self, action: #selector(saveTapped), forControlEvents: .touchUpInside)
        self.replyNode.addTarget(self, action: #selector(replyTapped), forControlEvents: .touchUpInside)
        self.shareNode.addTarget(self, action: #selector(shareTapped), forControlEvents: .touchUpInside)

        self.updateIcons()
    }

    @objc private func upvoteTapped() { self.onUpvote?() }
    @objc private func downvoteTapped() { self.onDownvote?() }
    @objc private func saveTapped() { self.onSave?() }
    @objc private func replyTapped() { self.onReply?() }
    @objc private func shareTapped() { self.onShare?() }

    // MARK: - Icons

    func setVoteStatus(_ status: RDKVoteStatus) {
        self.voteStatus = status
        self.updateIcons()
    }

    func setSaved(_ saved: Bool) {
        // Saving swaps the hollow bookmark for the solid "option-unsave".
        self.saveNode.setImage(self.icon(saved ? "option-unsave" : "option-save", tint: self.accent),
                               for: .normal)
    }

    private func updateIcons() {
        let upvoteColor = self.voteStatus == .upvoted ? ApolloPalette.upvote : self.accent
        let downvoteColor = self.voteStatus == .downvoted ? ApolloPalette.downvote : self.accent
        self.upvoteNode.setImage(self.icon("option-upvote", tint: upvoteColor), for: .normal)
        self.downvoteNode.setImage(self.icon("option-downvote", tint: downvoteColor), for: .normal)
        self.saveNode.setImage(self.icon(self.isSaved ? "option-unsave" : "option-save", tint: self.accent), for: .normal)
        self.replyNode.setImage(self.icon("option-reply", tint: self.accent), for: .normal)
        self.shareNode.setImage(self.icon("option-share", tint: self.accent), for: .normal)
    }

    private var accent: UIColor {
        return ThemeManager.shared.accentColor()
    }

    /// Measured: ~28pt tall, centred in a 44pt row.
    private func icon(_ name: String, tint: UIColor) -> UIImage? {
        return ApolloArtwork.glyph(named: name, height: 28, tint: tint)
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let buttons = [self.upvoteNode, self.downvoteNode, self.saveNode, self.replyNode, self.shareNode]
        // Five equal columns, so the glyphs land on the same x positions the
        // original draws them at (40, 121, 202, 283, 364 on a 402pt screen).
        let columns: [ASLayoutElement] = buttons.map { button in
            button.style.flexGrow = 1
            button.style.flexBasis = ASDimensionMakeWithFraction(0.2)
            let inset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 6, left: 0, bottom: 6, right: 0), child: button)
            inset.style.flexGrow = 1
            inset.style.flexBasis = ASDimensionMakeWithFraction(0.2)
            return inset
        }
        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                    justifyContent: .spaceBetween, alignItems: .stretch,
                                    children: columns)
        row.style.height = ASDimensionMake(44)
        return row
    }
}
