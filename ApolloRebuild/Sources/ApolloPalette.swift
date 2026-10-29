import UIKit
import AsyncDisplayKit

// ApolloPalette - the colours Apollo draws its post cells with
// Reconstructed from apollo-base 1.15.11 binary analysis and measured off
// 3x screenshots of the original app running in the simulator.
//
// These are NOT the theme accent: Apollo's vote colours are fixed brand
// colours, and the secondary text grey is its own value rather than
// UIColor.secondaryLabel. Every value below was sampled from pixels of the
// original build, so keep them literal instead of "tidying" them into
// semantic UIKit colours.
enum ApolloPalette {

    /// The "r/news by …" line, the points/comments/age row and the feed's
    /// self-text excerpt are all this grey (#666666), not secondaryLabel.
    static let secondaryText = UIColor(white: 0.4, alpha: 1)

    /// A post whose link has been visited before (Reddit's `visited` flag) is
    /// drawn dimmed. Measured: black title ink lands on #989898, #666666 body
    /// ink on #B3B3B3.
    static let readTitle = UIColor(white: 0.598, alpha: 1)
    static let readSecondaryText = UIColor(white: 0.702, alpha: 1)

    /// The ⋯ in the post cell, and the vote arrows when the post isn't voted on.
    static let iconGrey = UIColor(white: 0.522, alpha: 1)

    /// Upvote / downvote, sampled from the filled vote pill (#FF5D00 and
    /// #565FE3). Fixed brand colours: they stay the same in every theme.
    static let upvote = UIColor(red: 1, green: 93.0 / 255.0, blue: 0, alpha: 1)
    static let downvote = UIColor(red: 86.0 / 255.0, green: 95.0 / 255.0, blue: 227.0 / 255.0, alpha: 1)

    /// The link card's footer panel is systemGray6 and its separator is this
    /// light grey (#CCCCCC) - sampled from the original's link cards.
    static let linkFooterSeparator = UIColor(white: 0.8, alpha: 1)

    /// The 8pt band between cells, full bleed.
    static let cellSeparator = UIColor.systemGray6

    /// A link flair chip's fill.
    static let flairBackground = UIColor.systemGray6
}

extension UIColor {
    /// A colour that resolves differently in light and dark appearance.
    convenience init(light: UIColor, dark: UIColor) {
        self.init(dynamicProvider: { traits in
            return traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Resolve a dynamic colour the way the node's current traits would draw it.
    /// Texture lays out off the main thread, so never sample traits ambiently.
    func apolloResolved(_ traits: UITraitCollection) -> UIColor {
        return self.resolvedColor(with: traits)
    }
}

extension ASDisplayNode {
    /// A UITraitCollection that is safe to use while Texture is laying out off
    /// the main thread. Never read the node's `traitCollection` there.
    var apolloDrawingTraits: UITraitCollection {
        return ASPrimitiveTraitCollectionToUITraitCollection(self.primitiveTraitCollection())
    }
}
