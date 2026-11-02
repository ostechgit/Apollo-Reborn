import UIKit
import AsyncDisplayKit

// PostInfoNode - the two-line info block at the bottom of every post cell.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.PostInfoNode)
// and measured off 3x screenshots of the original.
//
// Large cell:
//
//     AskMen by (avatar) phantom_tweak            <- row 1
//     ^ 429  o 7  Q 4h                            <- row 2
//
// Compact cell shows the same rows, a little tighter.
//
// The original's node also owns author flair, awards, the cakeday cake, the
// "edited" marker and the upvote percentage, each behind its own setting; none
// of those are wired up here yet.
//
// The 22pt disc before the author name is the AUTHOR's own profile icon, not the
// subreddit's avatar: two posts from the same subreddit with different authors
// show different discs. Apollo looks those up in bulk through
// /api/user_data_by_account_ids (see ApolloUserIcons); the disc stays a neutral
// placeholder for authors Reddit has no icon for.

class PostInfoNode: ASDisplayNode {

    var link: RDKLink
    /// False in a specific subreddit's own feed, where repeating the
    /// subreddit's name under every post would be noise.
    let showsSubreddit: Bool
    let isCompact: Bool
    /// The comments header draws "in r/subreddit by …" plus the percentage
    /// liked, where the feed draws "r/subreddit by …" and the comment count.
    let isInsideComments: Bool
    /// Reddit's `visited` flag: the whole info block dims.
    var isRead: Bool = false

    let rowNode = ASDisplayNode()
    let statsRowNode = ASDisplayNode()

    private let inTextNode = ASTextNode()
    private let subredditTextNode = ASTextNode()
    private let byTextNode = ASTextNode()
    private let avatarNode = ASNetworkImageNode()
    private let authorTextNode = ASTextNode()
    private let pointsNode = ASTextNode()
    private let percentageNode = ASTextNode()
    private let commentsNode = ASTextNode()
    private let ageNode = ASTextNode()
    /// Sticky, locked and saved markers drawn after the author name. The
    /// original's assets are `inline-sticky`, `inline-locked` and
    /// `inline-saved`; its cakeday and awards nodes need data this model does
    /// not carry yet, so they are not drawn.
    private let stickyNode = ASImageNode()
    private let lockedNode = ASImageNode()
    private let savedNode = ASImageNode()
    /// Shown only on the author's cake day (data.author_cakeday).
    private let cakedayNode = ASImageNode()

    /// Called when the subreddit or author name is tapped. The cell forwards
    /// these to its screen (the original routes them through the same
    /// PostCellActionDelegate the vote buttons use).
    var onSubredditTapped: ((String) -> Void)?
    var onAuthorTapped: ((String) -> Void)?

    init(link: RDKLink, showsSubreddit: Bool = true, isCompact: Bool = false, isInsideComments: Bool = false) {
        self.link = link
        self.showsSubreddit = showsSubreddit
        self.isCompact = isCompact
        self.isInsideComments = isInsideComments

        // The parameters have to be set before super.init, so the avatar load
        // happens just below.
        super.init()
        self.automaticallyManagesSubnodes = true

        // A long subreddit or author name truncates on one line; the original
        // never wraps this row.
        for node in [self.inTextNode, self.subredditTextNode, self.byTextNode, self.authorTextNode] {
            node.maximumNumberOfLines = 1
            node.truncationMode = .byTruncatingTail
        }

        self.avatarNode.style.preferredSize = CGSize(width: 22, height: 22)
        self.avatarNode.cornerRadius = 11
        self.avatarNode.clipsToBounds = true
        self.avatarNode.backgroundColor = .systemGray5
        self.avatarNode.contentMode = .scaleAspectFill
        // Authors with no profile icon keep the neutral disc.
        self.avatarNode.placeholderColor = .systemGray5
        self.avatarNode.placeholderEnabled = true
        self.avatarNode.isUserInteractionEnabled = false

        for node in [self.subredditTextNode, self.authorTextNode] {
            node.isUserInteractionEnabled = true
            node.addTarget(self, action: #selector(nameTapped(_:)), forControlEvents: .touchUpInside)
        }

        for indicator in [self.stickyNode, self.lockedNode, self.savedNode, self.cakedayNode] {
            indicator.style.preferredSize = CGSize(width: 13, height: 13)
            indicator.contentMode = .scaleAspectFit
            indicator.isUserInteractionEnabled = false
        }
        self.cakedayNode.image = ApolloAssets.originalImage(named: "cakeday")
        self.stickyNode.image = ApolloAssets.image(named: "inline-sticky")
        self.lockedNode.image = ApolloAssets.image(named: "inline-locked")
        self.savedNode.image = ApolloAssets.image(named: "inline-saved")
        let tint = ApolloPalette.secondaryText
        for indicator in [self.stickyNode, self.lockedNode, self.savedNode] {
            indicator.image = indicator.image?.withTintColor(tint, renderingMode: .alwaysOriginal)
        }

        self.loadAvatar()
        self.update()
    }

    // MARK: - Author avatar

    /// Asks the shared store for the author's icon. It answers immediately when
    /// it already has one and otherwise once its bulk request comes back.
    private func loadAvatar() {
        ApolloUserIcons.shared.icon(forAccount: self.link.authorFullName) { [weak self] url in
            guard let self = self, let url = url else { return }
            self.avatarNode.url = url
        }
    }

    // MARK: - Content

    func update() {
        self.inTextNode.attributedText = self.nameText("in", read: self.isRead)
        self.subredditTextNode.attributedText = self.nameText(self.link.subreddit ?? "", read: self.isRead)
        self.byTextNode.attributedText = self.nameText("by", read: self.isRead)
        self.authorTextNode.attributedText = self.nameText(self.link.author ?? "[deleted]", read: self.isRead)

        self.pointsNode.attributedText = self.stat(icon: "posts-points-small",
                                                   value: PostFormatting.abbreviatedCount(self.link.score),
                                                   tint: self.pointsColor)
        self.commentsNode.attributedText = self.stat(icon: "posts-comments-small",
                                                     value: PostFormatting.abbreviatedCount(self.link.totalComments),
                                                     tint: self.secondaryColor)
        // The comments header replaces the comment count with the percentage
        // of people who upvoted, drawn with the "posts-liked" glyph.
        self.percentageNode.attributedText = self.stat(icon: "posts-liked",
                                                       value: String(format: "%.0f%%", self.link.upvoteRatio * 100),
                                                       tint: self.secondaryColor)
                self.ageNode.attributedText = self.stat(icon: "posts-clock-small",
                                                value: PostFormatting.relativeTime(since: self.link.createdUTC),
                                                tint: self.secondaryColor)
    }

    /// Remembers what row 1 needs so a rebind (cell reuse) can skip the
    /// attributed-text rebuild.
    private func nameText(_ string: String, read: Bool) -> NSAttributedString {
        return NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: read ? ApolloPalette.readSecondaryText : ApolloPalette.secondaryText
        ])
    }

    /// One stat: Apollo's own glyph followed by the number, 13pt.
    private func stat(icon: String, value: String, tint: UIColor) -> NSAttributedString {
        let result = NSMutableAttributedString()
        // posts-points-small is the thin arrow the info row uses (the heavier
        // "option-upvote" rendition belongs to the vote buttons).
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
        switch self.link.voteStatus {
        case .upvoted: return ApolloPalette.upvote
        case .downvoted: return ApolloPalette.downvote
        default: return self.secondaryColor
        }
    }

    private var secondaryColor: UIColor {
        return self.isRead ? ApolloPalette.readSecondaryText : ApolloPalette.secondaryText
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        // Row spacing measured at 5pt in a large cell, 4pt compact.
        let rowSpacing: CGFloat = self.isCompact ? 4 : 5
        var rowChildren: [ASLayoutElement] = []
        if self.showsSubreddit {
            if self.isInsideComments {
                rowChildren.append(self.inTextNode)
            }
            rowChildren.append(self.subredditTextNode)
            rowChildren.append(self.byTextNode)
        }
        rowChildren.append(contentsOf: [self.avatarNode, self.authorTextNode])
        // Indicators sit directly after the author, as the original draws them.
        // Appearance → "Show Awards" gates these.
        let showsAwards = UserDefaults.standard.object(forKey: "ShowAwards") as? Bool ?? true
        for url in showsAwards ? AwardIcons.urls(from: self.link.allAwardings, limit: 3) : [] {
            let award = ASNetworkImageNode()
            award.url = url
            award.contentMode = .scaleAspectFit
            award.isUserInteractionEnabled = false
            award.style.preferredSize = CGSize(width: 16, height: 16)
            award.style.spacingBefore = 5
            rowChildren.append(award)
        }
        let indicators: [(ASImageNode, Bool)] = [(self.stickyNode, self.link.stickied),
                                                 (self.lockedNode, self.link.locked),
                                                 (self.savedNode, self.link.saved),
                                                 (self.cakedayNode, self.link.authorCakeday)]
        for (node, shows) in indicators where shows {
            node.style.spacingBefore = 5
            rowChildren.append(node)
        }
        // The author gives up room first, then the subreddit, which is the
        // order the original truncates in ("…by aliceinswe…").
        self.authorTextNode.style.flexShrink = 2
        if self.showsSubreddit {
            self.subredditTextNode.style.flexShrink = 1
        }

        let first = ASStackLayoutSpec(direction: .horizontal, spacing: rowSpacing,
                                      justifyContent: .start, alignItems: .center,
                                      children: rowChildren)

        let stats = ASStackLayoutSpec(direction: .horizontal, spacing: 9,
                                      justifyContent: .start, alignItems: .center,
                                      children: self.isInsideComments
                                       ? [self.pointsNode, self.percentageNode, self.ageNode]
                                       : [self.pointsNode, self.commentsNode, self.ageNode])

        let rows = ASStackLayoutSpec(direction: .vertical, spacing: 8,
                                     justifyContent: .start, alignItems: .stretch,
                                     children: self.showsSubreddit ? [first, stats] : [stats])
        return ASWrapperLayoutSpec(layoutElement: rows)
    }

    // MARK: - Actions

    @objc private func nameTapped(_ sender: Any) {
        // The subreddit and author text nodes share this target; the tapped
        // node tells them apart.
        guard let node = sender as? ASDisplayNode else { return }
        if node === self.subredditTextNode {
            if let subreddit = self.link.subreddit {
                self.onSubredditTapped?(subreddit)
            }
        } else if let author = self.link.author {
            self.onAuthorTapped?(author)
        }
    }
}

// PostFormatting - compact counts and ages, as shown on posts and comments
enum PostFormatting {

    /// A post's link flair, as text. Flairs can mix text with Reddit emoji
    /// (`link_flair_richtext`): the text pieces are joined and the emoji are
    /// left out for now, because drawing them means fetching each emoji
    /// rendition and building the chip out of it.
    static func flairText(for link: RDKLink) -> String? {
        if let richtext = link.linkFlairRichtext, !richtext.isEmpty {
            let text = richtext.compactMap { entry -> String? in
                guard (entry["e"] as? String) == "text" else { return nil }
                return entry["t"] as? String
            }.joined().trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
            return nil
        }
        let plain = link.linkFlairText?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let flair = plain, !flair.isEmpty else { return nil }
        // ":snoo_tableflip::table_flip: Political Freakout :snoo_facepalm:"
        return flair.replacingOccurrences(of: ":[a-z0-9_+-]+:", with: "",
                                          options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // 999 -> "999", 1204 -> "1.2k", 18342 -> "18.3k", 1_500_000 -> "1.5m"
    static func abbreviatedCount(_ count: Int) -> String {
        let magnitude = abs(count)
        func format(_ value: Double, _ suffix: String) -> String {
            let rounded = (value * 10).rounded() / 10
            let text = rounded.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(rounded)) : String(format: "%.1f", rounded)
            return (count < 0 ? "-" : "") + text + suffix
        }
        if magnitude >= 1_000_000 {
            return format(Double(magnitude) / 1_000_000, "m")
        }
        if magnitude >= 1_000 {
            return format(Double(magnitude) / 1_000, "k")
        }
        return String(count)
    }

    // "now", "5m", "3h", "2d", "4mo", "1y"
    static func relativeTime(since date: Date?, now: Date = Date()) -> String {
        guard let date = date else { return "" }
        let seconds = max(0, now.timeIntervalSince(date))
        switch seconds {
        case ..<60: return "now"
        case ..<3600: return "\(Int(seconds / 60))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        case ..<2_592_000: return "\(Int(seconds / 86_400))d"
        case ..<31_536_000: return "\(Int(seconds / 2_592_000))mo"
        default: return "\(Int(seconds / 31_536_000))y"
        }
    }
}

extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
