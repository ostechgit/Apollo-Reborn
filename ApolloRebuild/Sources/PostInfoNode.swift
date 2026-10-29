import UIKit
import AsyncDisplayKit

// PostInfoNode - the "r/subreddit • u/author • 3h • domain" line under a post title
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original also shows subreddit icons, author flair, awards and the upvote
// percentage, each behind a setting.

class PostInfoNode: ASDisplayNode {
    
    var link: RDKLink
    let showsSubreddit: Bool
    private let textNode = ASTextNode()
    
    init(link: RDKLink, showsSubreddit: Bool = true) {
        self.link = link
        self.showsSubreddit = showsSubreddit
        super.init()
        self.automaticallyManagesSubnodes = true
        self.textNode.maximumNumberOfLines = 1
        self.textNode.truncationMode = .byTruncatingTail
        self.update()
    }
    
    func update() {
        var parts: [String] = []
        if self.showsSubreddit, let subreddit = self.link.subreddit {
            parts.append("r/" + subreddit)
        }
        parts.append("u/" + (self.link.author ?? "" ?? "[deleted]"))
        parts.append(PostFormatting.relativeTime(since: self.link.createdUTC))
        if !self.link.selfPost, let domain = self.link.domain, !domain.isEmpty, !domain.hasPrefix("self.") {
            parts.append(domain)
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let text = NSMutableAttributedString(string: parts.joined(separator: " \u{2022} "), attributes: attributes)
        if self.link.distinguished == "moderator" {
            text.append(NSAttributedString(string: " \u{2022} MOD", attributes: [
                .font: UIFont.preferredFont(forTextStyle: .footnote).bold(),
                .foregroundColor: UIColor.systemGreen
            ]))
        }
        self.textNode.attributedText = text
    }
    
    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        return ASWrapperLayoutSpec(layoutElement: self.textNode)
    }
}

// PostFormatting - compact counts and ages, as shown on posts and comments
enum PostFormatting {
    
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
