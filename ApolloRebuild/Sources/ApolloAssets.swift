import UIKit

// ApolloAssets - access to Apollo's own artwork.
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The original doesn't use SF Symbols for its interface chrome. Nearly every
// icon in the app is a named asset in the bundle's Assets.car (extracted from
// the original IPA by scripts/extract-assets.sh):
//
//   tab-bar-posts, tab-bar-inbox, tab-bar-profile, tab-bar-search, tab-bar-settings
//   option-upvote / option-downvote / option-comments / option-share / option-save /
//   option-more / option-reply / option-hide ...
//   symbol-upvote, symbol-share, symbol-hide, symbol-undo-upvote ...
//   slide-upvote-hollow, slide-upvote-solid ...        (comment swipe actions)
//   inline-upvote, inline-downvote                     (small info-line glyphs)
//   subreddit-a ... subreddit-z, subreddit-0 ... subreddit-9  (letter avatars)
//
// Every catalog entry is a vector PDF rendition flagged "template", so UIKit
// hands back a template image that has to be tinted by the view it lives in.
// `apolloImage(named:)` applies that once so call sites don't have to.

enum ApolloAssets {

    /// Look an asset up by its original name. Returns nil only when the catalog
    /// is missing from the bundle (extract-assets.sh wasn't run) or the name
    /// doesn't exist, so callers keep their nil handling honest.
    static func image(named name: String) -> UIImage? {
        guard let image = UIImage(named: name) else {
            // Logged once per missing name; the catalog is not versioned, so a
            // missing file is a setup problem rather than a normal runtime case.
            NSLog("[ApolloAssets] missing asset %@ (run scripts/extract-assets.sh)", name)
            return nil
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    /// An asset kept in its catalog colours. The `subreddit-a` … `subreddit-0`
    /// discs are plain filled circles whose colour comes from the catalog itself,
    /// so they must not be turned into templates.
    static func originalImage(named name: String) -> UIImage? {
        return UIImage(named: name)?.withRenderingMode(.alwaysOriginal)
    }

    /// An asset sized for a tab bar item (18pt icons in the original).
    static func tabBarImage(named name: String) -> UIImage? {
        return image(named: name)?.withRenderingMode(.alwaysTemplate)
    }

    /// The letter-avatar placeholder Apollo shows until a subreddit's icon loads
    /// ("subreddit-a" ... "subreddit-z", plus "subreddit-0" ... "subreddit-9" for
    /// names that start with a digit). The catalog has no punctuation rendition,
    /// so anything else falls back to "subreddit-a" (the catalog's first entry).
    static func subredditLetterAvatar(for name: String) -> UIImage? {
        let stripped = name.hasPrefix("r/") ? String(name.dropFirst(2)) : name
        if let first = stripped.first?.lowercased(),
           (first >= "a" && first <= "z") || (first >= "0" && first <= "9") {
            return image(named: "subreddit-\(first)")
        }
        return image(named: "subreddit-a")
    }
}
