import UIKit
import AsyncDisplayKit

// LinkButtonNode - the card Apollo draws for a post that links off Reddit.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.LinkButtonNode)
// and measured at 3x off the original's feed.
//
// The native card is much barer than a web link preview: a 16:9 thumbnail and
// one footer row that says where the link goes. There is no page title, site
// name or description in it - the post title above the card is the only title,
// and the footer is just the URL's host and path.
//
// Measured (370pt wide card, light appearance):
//
//   * card inset 16pt from the cell's edges, corner radius 10, clips its content
//   * thumbnail on top: exactly 16:9 (0.5625, the ratio the original feeds to
//     ASRatioLayoutSpec), edge to edge, aspect filled
//   * footer 47pt tall, fill systemGray6
//   * a 30pt type badge 10pt from the card's left, vertically centred
//   * a 1pt #CCCCCC separator, 36pt tall, 10pt after the badge
//   * the link text (host + path) 12pt after the separator, 15pt #666666,
//     one line, tail truncated
//   * Apollo's "disclosure-indicator" chevron 12pt in from the card's right
//
// The original also carries a video playhead overlay, a tweet card, a Wikipedia
// description card, an NSFW/spoiler veil and a compact (thumbnail-on-the-left)
// form. None of those are wired up here yet.

class LinkButtonNode: ASControlNode {

    let link: RDKLink

    private let thumbnailNode = ASNetworkImageNode()
    private let typeIconNode = ASImageNode()
    private let separatorNode = ASDisplayNode()
    private let urlTextNode = ASTextNode()
    private let chevronNode = ASImageNode()

    private static let footerHeight: CGFloat = 47

    init(link: RDKLink) {
        self.link = link
        super.init()
        self.automaticallyManagesSubnodes = true
        self.cornerRadius = 10
        self.clipsToBounds = true
        // The node itself is the tap target; nothing inside may swallow the touch.
        self.backgroundColor = .systemGray6

        self.thumbnailNode.contentMode = .scaleAspectFill
        self.thumbnailNode.clipsToBounds = true
        self.thumbnailNode.placeholderColor = .secondarySystemBackground
        self.thumbnailNode.placeholderEnabled = true
        self.thumbnailNode.isUserInteractionEnabled = false
        self.thumbnailNode.url = self.link.previewImages?.first?.url.flatMap(URL.init(string:))

        self.typeIconNode.style.preferredSize = CGSize(width: 30, height: 30)
        self.typeIconNode.image = ApolloAssets.image(named: self.typeIconName)?
            .withTintColor(.systemGray, renderingMode: .alwaysOriginal)
        self.typeIconNode.isUserInteractionEnabled = false

        self.separatorNode.style.preferredSize = CGSize(width: 1, height: 36)
        self.separatorNode.backgroundColor = ApolloPalette.linkFooterSeparator
        self.separatorNode.isUserInteractionEnabled = false

        self.urlTextNode.attributedText = NSAttributedString(string: self.displayedURL,
                                                            attributes: [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: ApolloPalette.secondaryText
        ])
        self.urlTextNode.maximumNumberOfLines = 1
        self.urlTextNode.truncationMode = .byTruncatingTail
        self.urlTextNode.style.flexShrink = 1
        self.urlTextNode.isUserInteractionEnabled = false

        self.chevronNode.image = ApolloAssets.image(named: "disclosure-indicator")?
            .withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
        self.chevronNode.style.preferredSize = CGSize(width: 9, height: 15)
        self.chevronNode.isUserInteractionEnabled = false
    }

    // MARK: - Text

    /// "bbc.com/news/articles/cq8jzkpjr28vo": the URL without its scheme, which
    /// is what the original's footer shows.
    private var displayedURL: String {
        guard let url = self.link.url.flatMap(URL.init(string:)) else { return self.link.domain ?? "" }
        let host = url.host ?? ""
        let path = url.path
        if path.isEmpty || path == "/" { return host }
        return host + path
    }

    /// Which badge the card shows. The catalog's link-button-* set is one icon
    /// per kind of destination; a plain web page gets the Safari compass.
    private var typeIconName: String {
        guard let host = self.link.url.flatMap(URL.init(string:))?.host?.lowercased() else {
            return "link-button-safari"
        }
        if host.contains("wikipedia.org") { return "link-button-wikipedia" }
        if host.contains("twitter.com") || host.contains("x.com") { return "link-button-twitter" }
        if host.contains("xkcd.com") { return "link-button-xkcd" }
        if host == "reddit.com" || host.hasSuffix(".redd.it") { return "link-button-reddit" }
        return "link-button-safari"
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        // 16:9, whatever the source image's own aspect is. The original hard-codes
        // this ratio for the card's thumbnail.
        let thumbnail: ASLayoutElement = ASRatioLayoutSpec(ratio: 0.5625, child: self.thumbnailNode)

        self.urlTextNode.style.spacingBefore = 12
        self.typeIconNode.style.spacingAfter = 10
        self.separatorNode.style.spacingAfter = 0
        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1

        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                    justifyContent: .start, alignItems: .center,
                                    children: [self.typeIconNode, self.separatorNode,
                                               self.urlTextNode, spacer, self.chevronNode])

        // 36pt separator plus 5.5pt either side is the 47pt footer.
        let footer = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 5.5, left: 10, bottom: 5.5, right: 12),
                                      child: row)

        let stack = ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                      justifyContent: .start, alignItems: .stretch,
                                      children: [thumbnail, footer])
        return stack
    }
}
