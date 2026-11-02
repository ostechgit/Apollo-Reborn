import UIKit
import AsyncDisplayKit

// CompactPostCellNode - the feed's compact row.
//
// Reconstructed from apollo-base 1.15.11: the original ships both
// `LargePostCellNode` and `CompactPostCellNode`, and the feed's ⋯ menu switches
// between them with "Compact Posts" / "Large Thumbnails" (both titles recovered
// in `src/ApolloNativeActionMetadata.h`). The compact row is one line of title
// plus the info row, with a square thumbnail on the trailing edge — which is why
// the icon in that menu is `option-compact-thumbnails-right`.
class CompactPostCellNode: ASCellNode {

    private let link: RDKLink
    private let titleNode = ASTextNode()
    private let infoNode: PostInfoNode
    private let thumbnailNode = ASNetworkImageNode()
    private let separatorNode = ASDisplayNode()
    private let showsThumbnail: Bool

    weak var actionDelegate: PostCellActionDelegate?

    init(link: RDKLink, inSpecificSubreddit: Bool = false, showsThumbnail: Bool = true) {
        self.link = link
        // Stock's Appearance setting can hide compact thumbnails entirely
        // (`CompactModeHideThumbnails`), independently of whether the link has one.
        let hidden = UserDefaults.standard.bool(forKey: "CompactModeHideThumbnails")
        self.showsThumbnail = showsThumbnail && !hidden
            && (link.thumbnailURL != nil || link.hasPreviewImage)
        self.infoNode = PostInfoNode(link: link, showsSubreddit: !inSpecificSubreddit,
                                     isCompact: true, isInsideComments: false)
        super.init()
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.backgroundColor = .systemBackground

        self.titleNode.maximumNumberOfLines = 2
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.attributedText = NSAttributedString(string: link.title ?? "", attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.label,
        ])

        if self.showsThumbnail {
            let url = link.thumbnailURL.flatMap(URL.init(string:))
                ?? link.previewImage(forWidth: 120, scale: UIScreen.main.scale)?.url.flatMap(URL.init(string:))
            let metrics = Self.thumbnailMetrics()
            self.thumbnailNode.url = url
            self.thumbnailNode.contentMode = .scaleAspectFill
            self.thumbnailNode.clipsToBounds = true
            self.thumbnailNode.cornerRadius = metrics.radius
            self.thumbnailNode.placeholderColor = .secondarySystemBackground
            self.thumbnailNode.placeholderEnabled = true
            self.thumbnailNode.isUserInteractionEnabled = false
            self.thumbnailNode.style.preferredSize = CGSize(width: metrics.size, height: metrics.size)
        }

        self.separatorNode.backgroundColor = .separator
        self.separatorNode.style.height = ASDimension(unit: .points, value: 0.5)
        self.separatorNode.isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Stock's Appearance → Thumbnail Size setting (`CompactPostsThumbnailSize`
    /// = small | medium | large).
    ///
    /// The corner radii are recovered from the binary (5 / 9 / 10, read at
    /// `FUN_1006f0f60`). The point sizes are **not** recovered — Apollo sets them
    /// in a layout helper that only carries a 4pt inset constant — so the three
    /// sizes below are estimates and should be replaced once measured against
    /// the real app.
    private static func thumbnailMetrics() -> (size: CGFloat, radius: CGFloat) {
        switch UserDefaults.standard.string(forKey: "CompactPostsThumbnailSize") {
        case "medium": return (64, 9)
        case "large": return (72, 10)
        default: return (56, 5)      // "small", and the unset default
        }
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let text = ASStackLayoutSpec(direction: .vertical, spacing: 6,
                                     justifyContent: .start, alignItems: .stretch,
                                     children: [self.titleNode, self.infoNode])
        text.style.flexGrow = 1
        text.style.flexShrink = 1
        text.style.minWidth = ASDimension(unit: .points, value: 0)

        var rowChildren: [ASLayoutElement] = [text]
        if self.showsThumbnail {
            self.thumbnailNode.style.spacingBefore = 12
            rowChildren.append(self.thumbnailNode)
        }
        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                    justifyContent: .start, alignItems: .center,
                                    children: rowChildren)
        let inset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16),
                                      child: row)
        return ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                 justifyContent: .start, alignItems: .stretch,
                                 children: [inset, self.separatorNode])
    }
}
