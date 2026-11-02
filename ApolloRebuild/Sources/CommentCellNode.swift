import UIKit
import AsyncDisplayKit

// CommentMedia - one image or gif embedded in a comment body.
//
// Reddit hands the comment's own media_metadata alongside the body, so both
// the URL and the true pixel size are known before the picture downloads
// (measured on the original: an inline comment image is drawn at the text
// column's full width, aspect preserved, with rounded corners).
struct CommentMedia {
    let url: URL
    let width: CGFloat
    let height: CGFloat
    /// Animated media (giphy, and Reddit's own gif previews) also carries an
    /// MP4 rendition, which is what the original plays inline. Nil for stills.
    var videoURL: URL? = nil

    var isAnimated: Bool { self.videoURL != nil }
}

enum CommentBody {

    /// Hosts whose direct links the original draws as pictures rather than as
    /// link cards or raw text.
    private static let imageHosts = ["i.redd.it", "preview.redd.it", "i.imgur.com", "b.thumbs.redditmedia.com"]

    /// Splits a body into the markdown that should be drawn as text and the
    /// media that should be drawn as images below it.
    static func split(_ body: String?, mediaMetadata: [String: Any]?) -> (text: String, media: [CommentMedia]) {
        guard let body = body, !body.isEmpty else { return ("", []) }
        var text = body
        var media: [CommentMedia] = []

        // ![alt](target) - the form Reddit and Relay use for embedded images
        // and giphy: "![gif](giphy|l36kU80xPf0ojG0Er)".
        var searchStart = text.startIndex
        while let bang = text.range(of: "![", range: searchStart..<text.endIndex),
              let close = text.range(of: "](", range: bang.upperBound..<text.endIndex),
              let end = text.range(of: ")", range: close.upperBound..<text.endIndex) {
            let target = String(text[close.upperBound..<end.lowerBound])
            if let item = self.media(target, mediaMetadata) {
                media.append(item)
            }
            // The reference itself never survives into the drawn text: the
            // original draws it as an image, and when Reddit marks the media
            // invalid (a dead giphy id) it draws nothing rather than the raw
            // "![gif](giphy|…)" text.
            text.removeSubrange(bang.lowerBound...end.lowerBound)
            searchStart = text.startIndex
        }

        // Bare links to Reddit- or Imgur-hosted pictures are pictures too.
        var remaining: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let url = URL(string: trimmed), self.isImageURL(url), let item = self.media(trimmed, mediaMetadata) ?? self.mediaWithoutMetadata(url) {
                media.append(item)
            } else {
                remaining.append(line)
            }
        }
        text = remaining.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (text, media)
    }

    private static func isImageURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return self.imageHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) })
    }

    /// Resolves one body reference against media_metadata. "giphy|ID" is a key
    /// verbatim; picture URLs use their filename's media id.
    private static func media(_ target: String, _ mediaMetadata: [String: Any]?) -> CommentMedia? {
        guard let mediaMetadata = mediaMetadata, !mediaMetadata.isEmpty else { return nil }
        let key: String
        if target.contains("|") {
            // "giphy|ID" is Reddit's media id verbatim.
            key = target
        } else if let url = URL(string: target) {
            key = url.deletingPathExtension().lastPathComponent
        } else {
            key = target
        }
        guard let entry = mediaMetadata[key] as? [String: Any] else { return nil }
        let source = (entry["s"] as? [String: Any]) ?? ((entry["p"] as? [[String: Any]])?.last)
        guard let source = source else { return nil }
        let urlString = (source["u"] as? String) ?? (source["gif"] as? String) ?? (source["mp4"] as? String)
        guard let urlString = urlString, let url = URL(string: urlString) else { return nil }
        let width = CGFloat((source["x"] as? NSNumber)?.doubleValue ?? 0)
        let height = CGFloat((source["y"] as? NSNumber)?.doubleValue ?? 0)
        guard width > 0, height > 0 else { return nil }
        let mp4 = (source["mp4"] as? String).flatMap(URL.init(string:))
        return CommentMedia(url: url, width: width, height: height, videoURL: mp4)
    }

    /// A picture with no media_metadata entry still carries its own size in the
    /// query string ("?width=3464&height=2000").
    private static func mediaWithoutMetadata(_ url: URL) -> CommentMedia? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> CGFloat? {
            guard let raw = items.first(where: { $0.name == name })?.value, let number = Double(raw) else { return nil }
            return CGFloat(number)
        }
        guard let width = value("width"), let height = value("height"), width > 0, height > 0 else { return nil }
        return CommentMedia(url: url, width: width, height: height)
    }
}

// CommentCellNode - one comment in a thread.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.CommentCellNode)
// and measured off 3x screenshots of the original.
//
// Measured layout (light appearance, 402pt screen):
//
//     |  (avatar) Author  ↑ 35                    ... 17h
//     |  body text, wrapped, 15pt
//
//   * every reply level indents its column by 14pt: the text column starts at
//     16 + 14*depth, and the 30pt avatar disc sits at that same x
//   * the thread line is a 2pt bar whose left edge is 12*depth, i.e. 18pt left
//     of the reply's own text column, and it spans the whole cell's height
//   * the bar's colours are Apollo's CommentColorTheme (Rainbow by default):
//     #F24336 red, #FF922E orange, then the rest of the wheel
//   * the author name is 15pt semibold: accent blue when the commenter is the
//     post's author (OP), green for a distinguished moderator, else label
//   * the score is the thin up arrow glyph plus a 13pt grey number, the ⋯ and
//     the age sit on the right (age right-aligned 16pt in)
//   * a 0.5pt #CCCCCC hairline sits at the top of the cell, inset by 12*depth
//
// Not wired up yet: stickied comments, awards, the
// deleted/moderator banners, the "show post context" row, and the swipe
// gestures that vote/collapse a comment.

class CommentCellNode: ASCellNode, ASTextNodeDelegate, UIGestureRecognizerDelegate {

    private static let swipeThreshold: CGFloat = 70

    var onLinkTapped: ((URL) -> Void)?
    /// Tapping a picture embedded in the body opens the media viewer.
    var onMediaTapped: ((URL) -> Void)?
    /// A tap on the body text that is not on a link behaves like a tap on the
    /// row: it collapses or expands the comment.
    var onBodyTapped: (() -> Void)?
    /// Swiping a comment left opens the reply composer for it, which is what the
    /// original does (its swipe actions are disabled per direction in Settings).
    var onSwipedLeft: (() -> Void)?
    var onAuthorTapped: ((String) -> Void)?

    func textNode(_ textNode: ASTextNode, tappedLinkAttribute attribute: String,
                  value: Any, at point: CGPoint, textRange: NSRange) {
        if textNode === self.authorNode {
            if let author = self.comment.author, author != "[deleted]" { self.onAuthorTapped?(author) }
        } else if let url = value as? URL {
            self.onLinkTapped?(url)
        } else if let string = value as? String, let url = URL(string: string) {
            self.onLinkTapped?(url)
        }
    }

    let comment: RDKComment
    let depth: Int
    /// The post's author, used to draw that person's comments in the accent
    /// colour even when Reddit didn't set `is_submitter`.
    let postAuthor: String?

    /// The comment's own ••• menu. Attached to the cell's button so iOS draws
    /// the same sheet the nav-bar menus use (the original opens that same
    /// style of action menu from a comment's dots).
    /// Called when the reader taps the cell's ••• . The screen presents the
    /// native action sheet (Apollo's `ActionController`), not a UIMenu.
    var onMoreTapped: (() -> Void)?

    /// Collapsed by a tap: the body and the whole reply subtree are hidden, and
    /// the header row swaps the ⋯ and the age for a grey count badge and a
    /// disclosure chevron, as the original does.
    let isCollapsed: Bool
    /// How many replies are hidden behind a collapsed comment.
    let hiddenReplyCount: Int

    private let authorNode = ASTextNode()
    private let flairNode = ASTextNode()
    private let pointsNode = ASTextNode()
    /// The little grey pencil the original shows next to the score of a comment
    /// that has been edited.
    private let editedNode = ASImageNode()
    /// A pinned (stickied) or locked comment says so next to its author, using
    /// the same `inline-sticky` / `inline-locked` assets as the post header.
    private let stickyNode = ASImageNode()
    private let lockedNode = ASImageNode()
    private let cakedayNode = ASImageNode()
    /// A real UIButton, because the ••• menu is a native `UIMenu` and only a
    /// UIButton can show one (`showsMenuAsPrimaryAction`). Texture's
    /// ASButtonNode has no UIButton behind it, so it can't host a menu.
    private let moreOptionsNode = ASButtonNode()
    private let ageNode = ASTextNode()
    private let bodyNode = ASTextNode()
    /// Pictures and gifs embedded in the body, drawn below the text at the
    /// column's full width with the original's rounded corners.
    private var mediaNodes: [ASDisplayNode] = []
    private var mediaURLs: [URL] = []
    private var mediaRatios: [CGFloat] = []
    private var hasBodyText = false
    private let threadLineNode = ASDisplayNode()
    private let separatorNode = ASDisplayNode()
    private let collapseBadgeNode = ASDisplayNode()
    private let collapseCountNode = ASTextNode()
    private let collapseChevronNode = ASImageNode()

    /// Apollo's Rainbow comment colour theme, sampled at depth 1 and 2 and
    /// completed around the wheel.
    static let rainbowColors: [UIColor] = [
        UIColor(red: 242.0 / 255.0, green: 67.0 / 255.0, blue: 54.0 / 255.0, alpha: 1),
        UIColor(red: 255.0 / 255.0, green: 146.0 / 255.0, blue: 46.0 / 255.0, alpha: 1),
        UIColor(red: 246.0 / 255.0, green: 200.0 / 255.0, blue: 60.0 / 255.0, alpha: 1),
        UIColor(red: 88.0 / 255.0, green: 190.0 / 255.0, blue: 110.0 / 255.0, alpha: 1),
        UIColor(red: 64.0 / 255.0, green: 156.0 / 255.0, blue: 240.0 / 255.0, alpha: 1),
        UIColor(red: 170.0 / 255.0, green: 110.0 / 255.0, blue: 230.0 / 255.0, alpha: 1),
    ]

    static let textGrey = UIColor(white: 0.55, alpha: 1)
    static let moreOptionsGrey = UIColor(white: 0.72, alpha: 1)

    init(comment: RDKComment, depth: Int? = nil, postAuthor: String? = nil,
         isCollapsed: Bool = false, hiddenReplyCount: Int = 0) {
        self.comment = comment
        self.depth = depth ?? comment.depth
        self.postAuthor = postAuthor
        self.isCollapsed = isCollapsed
        self.hiddenReplyCount = hiddenReplyCount
        super.init()
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.backgroundColor = .systemBackground

        // Stock comment rows draw no avatar: the captured cell subnodes are three
        // ApolloButtonNodes, an ASTextNode and a MarkdownNode. The disc the rebuild
        // used to draw was a Reborn addition.

        self.bodyNode.delegate = self
        self.bodyNode.linkAttributeNames = [NSAttributedString.Key.link.rawValue]
        self.bodyNode.isUserInteractionEnabled = true
        self.authorNode.delegate = self
        self.authorNode.linkAttributeNames = [NSAttributedString.Key.link.rawValue]
        self.authorNode.isUserInteractionEnabled = true
        self.authorNode.maximumNumberOfLines = 1
        self.authorNode.truncationMode = .byTruncatingTail
        self.authorNode.style.flexShrink = 1
        self.authorNode.attributedText = NSAttributedString(string: comment.author ?? "[deleted]", attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: self.authorColor,
            .link: comment.author ?? ""
        ])

        if let flair = comment.authorFlairPlaintext, !flair.isEmpty {
            self.flairNode.maximumNumberOfLines = 1
            self.flairNode.attributedText = NSAttributedString(string: flair, attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: UIColor(red: 0.86, green: 0.55, blue: 0.10, alpha: 1)
            ])
        }

        self.pointsNode.attributedText = self.scoreText(comment.scoreHidden ? "\u{2013}" : PostFormatting.abbreviatedCount(comment.score),
                                                       tint: self.pointsColor)

        self.moreOptionsNode.style.preferredSize = CGSize(width: 24, height: 24)
        self.moreOptionsNode.isUserInteractionEnabled = true

        // The original marks an edited comment with a pencil beside its score,
        // not with an asterisk on the age.
        if comment.edited != nil {
            self.editedNode.image = ApolloAssets.image(named: "comment-edited")?
                .withTintColor(CommentCellNode.textGrey, renderingMode: .alwaysOriginal)
            self.editedNode.style.preferredSize = CGSize(width: 12, height: 12)
            self.editedNode.isUserInteractionEnabled = false
        }
        var age = PostFormatting.relativeTime(since: comment.createdUTC)
        self.ageNode.attributedText = NSAttributedString(string: age, attributes: [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: CommentCellNode.textGrey
        ])

        // Apollo draws an embedded picture as an image node under the body, so
        // the markdown text is the body with its media references taken out.
        let split = CommentBody.split(comment.body,
                                      mediaMetadata: comment.mediaMetadata as? [String: Any])
        self.hasBodyText = !split.text.isEmpty
        if self.hasBodyText {
            self.bodyNode.maximumNumberOfLines = 0
            self.bodyNode.attributedText = MarkdownText.attributedString(split.text, style: .comment)
        }
        for item in split.media {
            let node: ASDisplayNode
            if let videoURL = item.videoURL {
                // Animated media plays in place; the still stays available for
                // the full-screen viewer.
                node = CommentVideoNode(url: videoURL)
            } else {
                let imageNode = ASNetworkImageNode()
                imageNode.url = item.url
                imageNode.contentMode = .scaleAspectFill
                imageNode.cornerRadius = 10
                imageNode.clipsToBounds = true
                imageNode.placeholderColor = .secondarySystemBackground
                imageNode.placeholderEnabled = true
                node = imageNode
            }
            // The original opens the viewer from a tapped body image, so the
            // node must take the touch before the row's collapse gesture.
            node.isUserInteractionEnabled = true
            self.mediaURLs.append(item.url)
            self.mediaNodes.append(node)
            self.mediaRatios.append(item.height / max(item.width, 1))
        }

        if self.depth > 0 {
            self.threadLineNode.backgroundColor = CommentCellNode.rainbowColors[(self.depth - 1) % CommentCellNode.rainbowColors.count]
        }
        self.threadLineNode.isUserInteractionEnabled = false

        self.separatorNode.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.separatorNode.isUserInteractionEnabled = false

        // Collapsed rows swap the ⋯ / age for a grey count badge and a
        // disclosure chevron (measured off the original: a 20pt rounded square,
        // then the chevron 6pt to its right, both centred in the 30pt header).
        if self.isCollapsed {
            self.collapseBadgeNode.backgroundColor = .systemGray5
            self.collapseBadgeNode.cornerRadius = 6
            self.collapseBadgeNode.style.preferredSize = CGSize(width: 20, height: 20)
            self.collapseCountNode.attributedText = NSAttributedString(string: "\(self.hiddenReplyCount)", attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: CommentCellNode.textGrey
            ])
            self.collapseCountNode.style.flexShrink = 1
            self.collapseChevronNode.image = ApolloAssets.image(named: "disclosure-indicator-down")?
                .withTintColor(CommentCellNode.moreOptionsGrey, renderingMode: .alwaysOriginal)
            self.collapseChevronNode.style.preferredSize = CGSize(width: 12, height: 7)
            self.collapseChevronNode.isUserInteractionEnabled = false
        }
    }

    /// The ••• glyph and its target are attached once Texture loads the node.
    override func didLoad() {
        super.didLoad()
        self.moreOptionsNode.setImage(ApolloAssets.image(named: "inline-more-options")?
            .withTintColor(CommentCellNode.moreOptionsGrey, renderingMode: .alwaysOriginal),
                                      for: .normal)
        self.moreOptionsNode.addTarget(self, action: #selector(CommentCellNode.moreTapped),
                                       forControlEvents: .touchUpInside)
        // Attach taps once the nodes have views; doing it in init would force
        // every media view to load synchronously.
        for (index, node) in self.mediaNodes.enumerated() {
            let recognizer = UITapGestureRecognizer(target: self,
                action: #selector(CommentCellNode.mediaTapped(_:)))
            node.view.tag = index
            node.view.addGestureRecognizer(recognizer)
        }
        // ASTextNode takes every touch (it needs them for link highlighting), so
        // a tap on non-link text never reaches the table. Re-route it.
        let bodyTap = UITapGestureRecognizer(target: self, action: #selector(CommentCellNode.bodyTapped(_:)))
        bodyTap.cancelsTouchesInView = false
        bodyTap.delegate = self
        self.bodyNode.view.addGestureRecognizer(bodyTap)

        if self.onSwipedLeft != nil {
            // Horizontal-only: vertical drags stay with the table.
            let swipe = UIPanGestureRecognizer(target: self, action: #selector(CommentCellNode.panned(_:)))
            swipe.delegate = self
            swipe.maximumNumberOfTouches = 1
            self.view.addGestureRecognizer(swipe)
        }
    }

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self.view)
        switch recognizer.state {
        case .ended:
            if translation.x < -Self.swipeThreshold, abs(translation.x) > abs(translation.y) {
                self.onSwipedLeft?()
            }
        default:
            break
        }
    }

    /// Let the row's swipe coexist with the table's vertical scrolling.
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: self.view)
        return abs(velocity.x) > abs(velocity.y) && velocity.x < 0
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }

    @objc private func bodyTapped(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self.bodyNode.view)
        var name: NSString?
        if self.bodyNode.linkAttributeValue(at: point, attributeName: &name, range: nil) != nil {
            return   // the text node's own link handling owns this tap
        }
        self.onBodyTapped?()
    }

    @objc private func moreTapped() {
        self.onMoreTapped?()
    }

    @objc private func mediaTapped(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view, view.tag >= 0, view.tag < self.mediaURLs.count else { return }
        self.onMediaTapped?(self.mediaURLs[view.tag])
    }

    // MARK: - Colours

    /// OP comments are drawn in the accent blue, distinguished moderators in
    /// green, everyone else in the label colour.
    private var authorColor: UIColor {
        if self.comment.distinguished == "moderator" || self.comment.distinguished == "admin" {
            return UIColor.systemGreen
        }
        let author = self.comment.author ?? ""
        if self.comment.isSubmitter || (self.postAuthor.map { $0.caseInsensitiveCompare(author) == .orderedSame } ?? false) {
            return ThemeManager.shared.accentColor()
        }
        return .label
    }

    private var pointsColor: UIColor {
        if self.comment.upvoted { return ApolloPalette.upvote }
        if self.comment.downvoted { return ApolloPalette.downvote }
        return CommentCellNode.textGrey
    }

    private func scoreText(_ value: String, tint: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if let glyph = ApolloArtwork.glyph(named: "posts-points-small", height: 13, tint: tint) {
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

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        // The text column of a reply starts 14pt right of its parent's.
        let column = 16 + CGFloat(max(self.depth, 0)) * 14
        // The thread line sits 18pt left of the text column.
        let barLeft = CGFloat(max(self.depth, 0)) * 12

        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1

        var headerChildren: [ASLayoutElement] = [self.authorNode]
        if self.flairNode.attributedText != nil {
            headerChildren.append(self.flairNode)
        }
        let markers: [(ASImageNode, String, Bool)] = [(self.stickyNode, "inline-sticky", self.comment.stickied),
                                                      (self.lockedNode, "inline-locked", self.comment.isLocked),
                                                      (self.cakedayNode, "cakeday", self.comment.authorCakeday)]
        for (indicator, asset, shows) in markers where shows {
            // The cake keeps its own colours; the inline markers are tinted.
            indicator.image = asset == "cakeday"
                ? ApolloAssets.originalImage(named: asset)
                : ApolloAssets.image(named: asset)?
                    .withTintColor(CommentCellNode.moreOptionsGrey, renderingMode: .alwaysOriginal)
            // ASImageNode defaults to .scaleAspectFill, which distorts a 12pt
            // glyph; the post header's markers use .scaleAspectFit.
            indicator.contentMode = .scaleAspectFit
            indicator.style.preferredSize = CGSize(width: 12, height: 12)
            indicator.style.spacingBefore = 5
            indicator.isUserInteractionEnabled = false
            headerChildren.append(indicator)
        }
        headerChildren.append(self.pointsNode)
        if self.editedNode.image != nil {
            headerChildren.append(self.editedNode)
            self.editedNode.style.spacingBefore = 6
        }
        headerChildren.append(spacer)
        if self.isCollapsed {
            // The count sits inside the 20pt badge.
            let badge = ASOverlayLayoutSpec(child: self.collapseBadgeNode,
                                            overlay: ASCenterLayoutSpec(centeringOptions: .XY,
                                                                        sizingOptions: .minimumXY,
                                                                        child: self.collapseCountNode))
            headerChildren.append(contentsOf: [badge, self.collapseChevronNode])
            self.collapseChevronNode.style.spacingBefore = 6
        } else {
            headerChildren.append(contentsOf: [self.moreOptionsNode, self.ageNode])
            self.moreOptionsNode.style.spacingBefore = 4
            self.ageNode.style.spacingBefore = 10
        }
        self.authorNode.style.spacingBefore = 0
        self.pointsNode.style.spacingBefore = 8

        let header = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                       justifyContent: .start, alignItems: .center,
                                       children: headerChildren)

        // A collapsed comment draws only its header row.
        var contentChildren: [ASLayoutElement] = [header]
        if !self.isCollapsed {
            if self.hasBodyText {
                self.bodyNode.style.spacingBefore = 8
                contentChildren.append(self.bodyNode)
            }
            for (index, mediaNode) in self.mediaNodes.enumerated() {
                // ASRatioLayoutSpec takes the column's full width and derives the
                // height from the picture's own dimensions. The spacing belongs
                // to the spec, not the child inside it, or the blocks touch.
                let ratio = ASRatioLayoutSpec(ratio: self.mediaRatios[index], child: mediaNode)
                ratio.style.spacingBefore = 8
                contentChildren.append(ratio)
            }
        }
        let content = ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                        justifyContent: .start, alignItems: .stretch,
                                        children: contentChildren)

        // The thread line is a sibling of the content, not part of it: a strip
        // `column` wide holding the 2pt bar at `barLeft`. In a horizontal stack
        // with `.stretch` alignment the strip takes the content's full height,
        // which is what makes the line span the whole comment.
        let insetContent = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 8.5, left: 0, bottom: 8.5, right: 16),
                                             child: content)
        // The row is a fixed-width strip (the thread line / indent) plus the
        // text column. Without an explicit flexGrow the text column would be
        // measured at the full table width and run off the right edge, which
        // showed up as long URLs drawing past the screen.
        insetContent.style.flexGrow = 1
        insetContent.style.flexShrink = 1

        var rowChildren: [ASLayoutElement] = []
        if self.depth > 0 {
            self.threadLineNode.style.width = ASDimensionMake(2)
            // The bar covers the content box only, so its ends sit the same
            // 8.5pt in from the separators as the text does (measured on the
            // original: a 2-line reply's bar runs 9pt inside each hairline).
            let barStrip = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 8.5, left: barLeft, bottom: 8.5,
                                                                  right: column - barLeft - 2),
                                             child: self.threadLineNode)
            rowChildren.append(barStrip)
        } else {
            let padding = ASLayoutSpec()
            padding.style.width = ASDimensionMake(column)
            rowChildren.append(padding)
        }
        rowChildren.append(insetContent)
        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                    justifyContent: .start, alignItems: .stretch,
                                    children: rowChildren)
        // Same reason: the row has to fill the width the table measured it at.
        if constrainedSize.max.width.isFinite {
            row.style.width = ASDimensionMake(constrainedSize.max.width)
        }

        // The hairline at the top of the cell is inset by the depth indent.
        let separatorInset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: barLeft, bottom: 0, right: 0),
                                               child: self.separatorNode)
        self.separatorNode.style.height = ASDimensionMake(0.5)

        return ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                 justifyContent: .start, alignItems: .stretch,
                                 children: [separatorInset, row])
    }
}

// MoreCommentsCellNode - the row that stands in for comments Reddit did not
// send (Apollo.MoreCommentsCellNode).
// Reconstructed from apollo-base 1.15.11 binary analysis and measured off 3x
// screenshots of the original.
//
// Measured (the original's "13 more replies" row):
//
//   * the row carries its own thread line, at 12*depth, exactly like a
//     comment above it, and its hairline is inset the same 12*depth
//   * the text starts at the comment column, 16 + 14*depth: "N more replies"
//     (or "Continue thread" for a thread Reddit rolled up), 15pt semibold in
//     the accent blue
//   * a blue disclosure chevron (13pt wide) sits 16pt from the right edge
//   * the row is 39pt tall
//
// The original also has a loading activity indicator and, when replies were
// deleted, links to the explanation screen. Those states are not implemented.
class MoreCommentsCellNode: ASCellNode {

    private let textNode = ASTextNode()
    private let chevronNode = ASImageNode()
    private let threadLineNode = ASDisplayNode()
    private let separatorNode = ASDisplayNode()
    private let depth: Int

    init(more: RDKMoreComments, depth: Int) {
        self.depth = depth
        super.init()
        self.automaticallyManagesSubnodes = true
        self.selectionStyle = .none
        self.backgroundColor = .systemBackground

        let accent = ThemeManager.shared.accentColor()
        let count = more.count
        let text: String
        if more.isContinueThread {
            text = "Continue thread"
        } else {
            text = count == 1 ? "1 more reply" : "\(count) more replies"
        }
        self.textNode.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: accent
        ])
        self.textNode.style.flexShrink = 1

        self.chevronNode.image = ApolloAssets.image(named: "disclosure-indicator-down")?
            .withTintColor(accent, renderingMode: .alwaysOriginal)
        self.chevronNode.style.preferredSize = CGSize(width: 13, height: 7.5)
        self.chevronNode.isUserInteractionEnabled = false

        if self.depth > 0 {
            self.threadLineNode.backgroundColor =
                CommentCellNode.rainbowColors[(self.depth - 1) % CommentCellNode.rainbowColors.count]
        }
        self.threadLineNode.isUserInteractionEnabled = false

        self.separatorNode.backgroundColor = UIColor(white: 0.8, alpha: 1)
        self.separatorNode.isUserInteractionEnabled = false
    }

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        let column = 16 + CGFloat(max(self.depth, 0)) * 14
        let barLeft = CGFloat(max(self.depth, 0)) * 12

        let spacer = ASLayoutSpec()
        spacer.style.flexGrow = 1

        let textRow = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                        justifyContent: .start, alignItems: .center,
                                        children: [self.textNode, spacer, self.chevronNode])
        // 39pt tall row: an 18pt line plus 9pt above and 11.5pt below.
        let textInset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 9, left: 0, bottom: 11.5, right: 16),
                                          child: textRow)
        textInset.style.flexGrow = 1
        textInset.style.flexShrink = 1

        var rowChildren: [ASLayoutElement] = []
        if self.depth > 0 {
            self.threadLineNode.style.width = ASDimensionMake(2)
            // The bar runs the row's whole height (it touches both hairlines),
            // unlike a comment's, which is inset to the text's own box.
            let barStrip = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: barLeft, bottom: 0,
                                                                  right: column - barLeft - 2),
                                             child: self.threadLineNode)
            rowChildren.append(barStrip)
        } else {
            let padding = ASLayoutSpec()
            padding.style.width = ASDimensionMake(column)
            rowChildren.append(padding)
        }
        rowChildren.append(textInset)
        let row = ASStackLayoutSpec(direction: .horizontal, spacing: 0,
                                    justifyContent: .start, alignItems: .stretch,
                                    children: rowChildren)
        if constrainedSize.max.width.isFinite {
            row.style.width = ASDimensionMake(constrainedSize.max.width)
        }

        let separatorInset = ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: barLeft, bottom: 0, right: 0),
                                               child: self.separatorNode)
        self.separatorNode.style.height = ASDimensionMake(0.5)

        return ASStackLayoutSpec(direction: .vertical, spacing: 0,
                                 justifyContent: .start, alignItems: .stretch,
                                 children: [separatorInset, row])
    }
}
