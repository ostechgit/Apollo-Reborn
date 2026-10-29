import UIKit
import AsyncDisplayKit

// CrosspostNode - the card a crosspost's parent is drawn as, inside the feed cell.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.CrosspostNode)
// and measured off 3x screenshots of the original.
//
// A post that crossposts another post shows the PARENT's media, not its own
// (the crosspost itself has none), with a footer strip that says where it came
// from and what the parent scored:
//
//     [  parent media, edge to edge inside the card, top corners rounded  ]
//     [ (arrows) Awww  ^ 25  o 2                                        ]
//
// Measured (light appearance, 402pt screen):
//
//   * card inset 16pt from the cell's edges, corner radius 10, clip to bounds
//   * footer 41pt tall, fill systemGray6, its content inset 15pt
//   * the crosspost glyph (two crossing arrows) leads, #666666, about 16pt tall
//   * parent subreddit name 13pt #666666, 8pt after the glyph
//   * up arrow + score, then comment bubble + count, 8pt apart, same grey
//
// The original also prefers the parent subreddit's own icon here when it can
// fetch one (subredditIconNode, with the glyph as the placeholder); the rebuild
// draws the glyph, which is what the original shows whenever no icon is cached.

class CrosspostNode: ASControlNode {

    let crosspostParent: RDKLink
    let isCompact: Bool

    /// Called when the parent's media is tapped; the cell forwards it to the
    /// screen's post-cell delegate.
    var onTapped: (() -> Void)?

    private let mediaNode: RichMediaNode?
    private let crosspostIconNode = ASImageNode()
    private let subredditNode = ASTextNode()
    private let pointsNode = ASTextNode()
    private let commentsNode = ASTextNode()
    private let footerNode = ASDisplayNode()

    /// Measured: 41pt tall on a large cell.
    private static let footerHeight: CGFloat = 41

    init(crosspostParent: RDKLink, isCompact: Bool = false) {
        self.crosspostParent = crosspostParent
        self.isCompact = isCompact
        self.mediaNode = RichMediaNode(link: crosspostParent)
        super.init()
        self.automaticallyManagesSubnodes = true
        // The card is one clipped rounded rect: the media's top corners and the
        // footer's bottom corners come from this node's own radius.
        self.backgroundColor = .systemGray6
        self.cornerRadius = 10
        self.clipsToBounds = true

        self.crosspostIconNode.image = ApolloAssets.image(named: "crosspost-small")?
            .withTintColor(ApolloPalette.secondaryText, renderingMode: .alwaysOriginal)
        self.crosspostIconNode.style.preferredSize = CGSize(width: 16, height: 16)
        self.crosspostIconNode.isUserInteractionEnabled = false

        for node in [self.subredditNode, self.pointsNode, self.commentsNode] {
            node.maximumNumberOfLines = 1
            node.isUserInteractionEnabled = false
        }

        self.subredditNode.attributedText = self.text(self.crosspostParent.subreddit ?? "")
        self.pointsNode.attributedText = self.stat(icon: "posts-points-small",
                                                   value: PostFormatting.abbreviatedCount(self.crosspostParent.score),
                                                   tint: self.pointsColor)
        self.commentsNode.attributedText = self.stat(icon: "posts-comments-small",
                                                     value: PostFormatting.abbreviatedCount(self.crosspostParent.totalComments),
                                                     tint: ApolloPalette.secondaryText)

        self.footerNode.isUserInteractionEnabled = false

        self.mediaNode?.onTapped = { [weak self] in self?.onTapped?() }
    }

    // MARK: - Text

    private func text(_ string: String) -> NSAttributedString {
        return NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: ApolloPalette.secondaryText
        ])
    }

    /// Glyph + value, the same 13pt treatment the post info row uses.
    private func stat(icon: String, value: String, tint: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let glyph = ApolloArtwork.glyph(named: icon, height: 13, tint: tint) {
            let attachment = NSTextAttachment(image: glyph)
            attachment.bounds = CGRect(x: 0, y: -2, width: glyph.size.width, height: glyph.size.height)
            result.append(NSAttributedString(attachment: attachment))
            result.append(NSAttributedString(string: "\u{2009}"))
        }
        result.append(NSAttributedString(string: value, attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: tint
        ]))
        return result
    }

    private var pointsColor: UIColor {
        switch self.crosspostParent.voteStatus {
        case .upvoted: return ApolloPalette.upvote
        case .downvoted: return ApolloPalette.downvote
        default: return ApolloPalette.secondaryText
        }
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1

        let footerRow = ASStackLayoutSpec(direction: .horizontal, spacing: 8,
                                          justifyContent: .start, alignItems: .center,
                                          children: [self.crosspostIconNode, self.subredditNode,
                                                     self.pointsNode, self.commentsNode])
        // The strip is 41pt tall; the row is 16pt tall (the crosspost glyph),
        // so 12.5pt either side centres it.
        let footer = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 12.5, left: 15, bottom: 12.5, right: 15),
                                       child: footerRow)

        var children: [ASLayoutElement] = []
        if let mediaNode = self.mediaNode {
            children.append(mediaNode)
        } else {
            // A self post has no media of its own; the footer still stands on
            // its own as the card's content.
            children.append(ASDisplayNode())
        }
        children.append(footer)

        let stack = ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                      justifyContent: .start, alignItems: .stretch,
                                      children: children)
        // The card is inset 16pt by the cell; this node is the card.
        return ASWrapperLayoutSpec(layoutElement: stack)
    }
}
