import UIKit
import AsyncDisplayKit

// PostCellActionDelegate - what a post cell asks its screen to do
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.PostCellActionDelegate).
protocol PostCellActionDelegate: AnyObject {
    func postCell(_ cell: LargePostCellNode, didTapVote direction: RDKVoteDirection, on link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapSaveOn link: RDKLink)
    func postCell(_ cell: LargePostCellNode, didTapMediaOf link: RDKLink)
}

// LargePostCellNode - a post in the feed: title, info line, media, and actions
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Subnode names follow the original (titleNode, postInfoNode, richMediaNode,
// optionButtonsNode). The original's RichMediaNode plays video and GIFs inline and
// handles galleries, crossposts and link previews; here media is a preview image
// that the screen opens on tap.

class LargePostCellNode: ASCellNode {
    
    var link: RDKLink
    let inSpecificSubreddit: Bool
    // The comments header shows the whole self text; the feed shows an excerpt
    let isInsideComments: Bool
    weak var actionDelegate: PostCellActionDelegate?
    
    let titleNode = ASTextNode()
    let postInfoNode: PostInfoNode
    let selfTextNode = ASTextNode()
    let richMediaNode = ASNetworkImageNode()
    let optionButtonsNode = ASDisplayNode()
    
    private let mediaBadgeNode = ASTextNode()
    private let playIconNode = ASImageNode()
    private let obscuringNode: ASDisplayNode
    private let obscuringLabelNode = ASTextNode()
    private let scoreNode = ASTextNode()
    private let commentsNode = ASTextNode()
    private let upvoteButton = ASButtonNode()
    private let downvoteButton = ASButtonNode()
    private let saveButton = ASButtonNode()
    private let separatorNode = ASDisplayNode()
    
    private var isMediaRevealed = false
    
    // Previews taller than this get cropped, like a portrait photo in the feed
    private let maximumMediaAspectRatio: CGFloat = 1.25
    
    init(link: RDKLink, inSpecificSubreddit: Bool = false, isInsideComments: Bool = false) {
        self.link = link
        self.inSpecificSubreddit = inSpecificSubreddit
        self.isInsideComments = isInsideComments
        self.postInfoNode = PostInfoNode(link: link, showsSubreddit: !inSpecificSubreddit)
        self.obscuringNode = ASDisplayNode(viewBlock: {
            UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
        })
        super.init()
        
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.backgroundColor = .systemBackground
        
        self.titleNode.maximumNumberOfLines = 0
        self.selfTextNode.maximumNumberOfLines = isInsideComments ? 0 : 3
        self.selfTextNode.truncationMode = .byTruncatingTail
        
        self.richMediaNode.placeholderEnabled = true
        self.richMediaNode.placeholderColor = .secondarySystemBackground
        self.richMediaNode.backgroundColor = .secondarySystemBackground
        self.richMediaNode.contentMode = .scaleAspectFill
        self.richMediaNode.cornerRadius = 10
        self.richMediaNode.clipsToBounds = true
        self.richMediaNode.addTarget(self, action: #selector(mediaTapped), forControlEvents: .touchUpInside)
        
        self.playIconNode.image = UIImage(systemName: "play.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        self.playIconNode.style.preferredSize = CGSize(width: 52, height: 52)
        self.playIconNode.isUserInteractionEnabled = false
        
        self.mediaBadgeNode.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        self.mediaBadgeNode.cornerRadius = 6
        self.mediaBadgeNode.textContainerInset = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)
        self.mediaBadgeNode.isUserInteractionEnabled = false
        
        self.obscuringNode.cornerRadius = 10
        self.obscuringNode.clipsToBounds = true
        self.obscuringNode.isUserInteractionEnabled = false
        
        self.separatorNode.backgroundColor = .separator
        self.separatorNode.style.height = ASDimensionMake(0.5)
        
        for (button, action) in [(self.upvoteButton, #selector(upvoteTapped)), (self.downvoteButton, #selector(downvoteTapped)), (self.saveButton, #selector(saveTapped))] {
            button.style.preferredSize = CGSize(width: 40, height: 36)
            button.addTarget(self, action: action, forControlEvents: .touchUpInside)
        }
        self.upvoteButton.accessibilityLabel = "Upvote"
        self.downvoteButton.accessibilityLabel = "Downvote"
        
        self.updateContent()
        self.updateActionState()
    }
    
    // MARK: - Content
    
    private func updateContent() {
        let title = NSMutableAttributedString()
        func badge(_ text: String, _ color: UIColor) {
            title.append(NSAttributedString(string: text + "  ", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .caption1).bold(),
                .foregroundColor: color
            ]))
        }
        if self.link.stickied { badge("PINNED", .systemGreen) }
        if self.link.isNSFW { badge("NSFW", .systemRed) }
        if self.link.isSpoiler { badge("SPOILER", .secondaryLabel) }
        if let flair = self.link.linkFlairText, !flair.isEmpty { badge(flair, .systemBlue) }
        title.append(NSAttributedString(string: self.link.title ?? "", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .headline),
            .foregroundColor: self.link.visited ? UIColor.secondaryLabel : UIColor.label
        ]))
        self.titleNode.attributedText = title
        
        if self.link.selfPost, let selfText = self.link.selfText, !selfText.isEmpty {
            self.selfTextNode.attributedText = NSAttributedString(string: selfText, attributes: [
                .font: UIFont.preferredFont(forTextStyle: self.isInsideComments ? .body : .subheadline),
                .foregroundColor: self.isInsideComments ? UIColor.label : UIColor.secondaryLabel
            ])
        }
        
        var badgeText: String?
        if self.link.isGallery && self.link.galleryItemCount > 0 {
            badgeText = "\(self.link.galleryItemCount) photos"
        } else if !self.link.selfPost && !self.link.isVideo && !self.link.isImageLink, let domain = self.link.domain {
            badgeText = domain
        }
        if let badgeText = badgeText {
            self.mediaBadgeNode.attributedText = NSAttributedString(string: badgeText, attributes: [
                .font: UIFont.preferredFont(forTextStyle: .caption1).bold(),
                .foregroundColor: UIColor.white
            ])
        }
        
        let obscuredReason = self.link.isNSFW ? "NSFW" : (self.link.isSpoiler ? "Spoiler" : nil)
        if let reason = obscuredReason {
            self.obscuringLabelNode.attributedText = NSAttributedString(string: "\(reason) \u{2014} tap to show", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .subheadline).bold(),
                .foregroundColor: UIColor.label
            ])
        }
    }
    
    // Score, comment count and the vote/save buttons; call after changing the link's vote or saved state
    func updateActionState() {
        let scoreColor: UIColor
        switch self.link.voteStatus {
        case .upvoted: scoreColor = .systemOrange
        case .downvoted: scoreColor = .systemIndigo
        default: scoreColor = .secondaryLabel
        }
        let statAttributes: (UIColor) -> [NSAttributedString.Key: Any] = { color in
            [.font: UIFont.preferredFont(forTextStyle: .subheadline).bold(), .foregroundColor: color]
        }
        self.scoreNode.attributedText = self.statText(symbol: "arrow.up", text: PostFormatting.abbreviatedCount(self.link.score), attributes: statAttributes(scoreColor))
        self.commentsNode.attributedText = self.statText(symbol: "bubble.left", text: PostFormatting.abbreviatedCount(self.link.totalComments), attributes: statAttributes(.secondaryLabel))
        
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        func symbol(_ name: String, _ color: UIColor) -> UIImage? {
            return UIImage(systemName: name, withConfiguration: configuration)?.withTintColor(color, renderingMode: .alwaysOriginal)
        }
        self.upvoteButton.setImage(symbol(self.link.upvoted ? "arrow.up.circle.fill" : "arrow.up", self.link.upvoted ? .systemOrange : .secondaryLabel), for: .normal)
        self.downvoteButton.setImage(symbol(self.link.downvoted ? "arrow.down.circle.fill" : "arrow.down", self.link.downvoted ? .systemIndigo : .secondaryLabel), for: .normal)
        self.saveButton.setImage(symbol(self.link.saved ? "bookmark.fill" : "bookmark", self.link.saved ? .systemGreen : .secondaryLabel), for: .normal)
        self.saveButton.accessibilityLabel = self.link.saved ? "Unsave" : "Save"
        
        // Archived posts can't be voted on
        for button in [self.upvoteButton, self.downvoteButton] {
            button.isEnabled = !self.link.isArchived
            button.alpha = self.link.isArchived ? 0.4 : 1
        }
    }
    
    private func statText(symbol: String, text: String, attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let color = attributes[.foregroundColor] as? UIColor,
           let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))?.withTintColor(color, renderingMode: .alwaysOriginal) {
            result.append(NSAttributedString(attachment: NSTextAttachment(image: image)))
            result.append(NSAttributedString(string: " "))
        }
        result.append(NSAttributedString(string: text, attributes: attributes))
        return result
    }
    
    // Texture lays out off the main thread, so read the scale from the node's traits rather than UIScreen
    private var displayScale: CGFloat {
        let scale = self.primitiveTraitCollection().displayScale
        return scale > 0 ? scale : 3
    }
    
    private var showsMedia: Bool {
        return !self.link.selfPost && self.link.hasPreviewImage
    }
    
    private var isObscured: Bool {
        return (self.link.isNSFW || self.link.isSpoiler) && !self.isMediaRevealed
    }
    
    // MARK: - Layout
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let horizontalInset: CGFloat = 16
        var children: [ASLayoutElement] = [self.titleNode]
        
        if self.showsMedia {
            let mediaWidth = max(constrainedSize.max.width - horizontalInset * 2, 1)
            if let preview = self.link.previewImage(forWidth: mediaWidth, scale: self.displayScale) {
                let url = URL(string: preview.url ?? "")
                if self.richMediaNode.url != url {
                    self.richMediaNode.url = url
                }
                let ratio = min(CGFloat(preview.height) / CGFloat(max(preview.width, 1)), self.maximumMediaAspectRatio)
                var media: ASLayoutElement = ASRatioLayoutSpec(ratio: ratio, child: self.richMediaNode)
                
                var overlays: [ASLayoutElement] = []
                if self.link.isVideo {
                    overlays.append(ASCenterLayoutSpec(centeringOptions: .XY, sizingOptions: [], child: self.playIconNode))
                }
                if self.mediaBadgeNode.attributedText != nil {
                    overlays.append(ASRelativeLayoutSpec(horizontalPosition: .end, verticalPosition: .end, sizingOption: [],
                                                         child: ASInsetLayoutSpec(insets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8), child: self.mediaBadgeNode)))
                }
                if self.isObscured {
                    let label = ASCenterLayoutSpec(centeringOptions: .XY, sizingOptions: [], child: self.obscuringLabelNode)
                    overlays.append(ASOverlayLayoutSpec(child: self.obscuringNode, overlay: label))
                }
                for overlay in overlays {
                    media = ASOverlayLayoutSpec(child: media, overlay: overlay)
                }
                children.append(media)
            }
        } else if self.selfTextNode.attributedText != nil {
            children.append(self.selfTextNode)
        }
        
        children.append(self.postInfoNode)
        
        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1
        let stats = ASStackLayoutSpec(direction: .horizontal, spacing: 14, justifyContent: .start, alignItems: .center, children: [self.scoreNode, self.commentsNode])
        let buttons = ASStackLayoutSpec(direction: .horizontal, spacing: 4, justifyContent: .end, alignItems: .center, children: [self.upvoteButton, self.downvoteButton, self.saveButton])
        let actions = ASStackLayoutSpec(direction: .horizontal, spacing: 0, justifyContent: .start, alignItems: .center, children: [stats, spacer, buttons])
        actions.style.spacingBefore = -6
        children.append(actions)
        
        let content = ASStackLayoutSpec(direction: .vertical, spacing: 10, justifyContent: .start, alignItems: .stretch, children: children)
        let inset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 14, left: horizontalInset, bottom: 4, right: horizontalInset), child: content)
        return ASStackLayoutSpec(direction: .vertical, spacing: 0, justifyContent: .start, alignItems: .stretch, children: [inset, self.separatorNode])
    }
    
    // MARK: - Actions
    
    @objc private func mediaTapped() {
        if self.isObscured {
            self.isMediaRevealed = true
            self.setNeedsLayout()
            return
        }
        self.actionDelegate?.postCell(self, didTapMediaOf: self.link)
    }
    
    @objc private func upvoteTapped() {
        self.actionDelegate?.postCell(self, didTapVote: self.link.upvoted ? .none : .up, on: self.link)
    }
    
    @objc private func downvoteTapped() {
        self.actionDelegate?.postCell(self, didTapVote: self.link.downvoted ? .none : .down, on: self.link)
    }
    
    @objc private func saveTapped() {
        self.actionDelegate?.postCell(self, didTapSaveOn: self.link)
    }
}
