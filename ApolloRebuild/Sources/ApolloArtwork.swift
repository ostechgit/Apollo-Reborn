import UIKit

// ApolloArtwork - the few pieces of a post cell that are drawn rather than
// made of separate nodes.
// Reconstructed from apollo-base 1.15.11 binary analysis and measured off 3x
// screenshots of the original.
//
// Two things in the large post cell are single images in the original rather
// than stacks of nodes:
//
//   * the link flair chip on the title's last line (18pt tall rounded pill),
//   * the vote button (32x32, bare arrow when neutral, brand-coloured rounded
//     square with a white arrow once the post is voted on).
//
// Everything else in the cell comes out of Apollo's own asset catalog, so this
// file draws only what the catalog has no rendition for. Each image is cached
// per (content, state, scale): Texture asks for layout off the main thread and
// re-asks on every rebind, so rendering on each call would be wasteful.

enum ApolloArtwork {

    // MARK: - Link flair chip

    /// The chip Apollo puts after a post's title for link flair ("Release",
    /// "High Sodium Content"). Measured: 18pt tall, ~9pt corner radius, 6pt
    /// horizontal text inset, 14pt text, #858585 text on systemGray6.
    static func flairChip(text: String, traits: UITraitCollection) -> UIImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let scale = traits.displayScale > 0 ? traits.displayScale : 3
        let font = UIFont.systemFont(ofSize: 14, weight: .medium)
        let textColor = ApolloPalette.iconGrey
        let background = ApolloPalette.flairBackground.resolvedColor(with: traits)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]

        let key = "flair|\(trimmed)|\(background.hashValue)|\(scale)"
        if let cached = flairCache.value(key) { return cached }

        // 18pt tall, and as wide as the text plus 6pt on each side
        let height: CGFloat = 18
        let textSize = (trimmed as NSString).size(withAttributes: attributes)
        let width = ceil(textSize.width) + 12

        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                           format: rendererFormat(scale: scale)).image { context in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            background.setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: height / 2).fill()
            // Centre the text's cap height in the chip rather than the whole
            // line box, which is what the original's chip looks like.
            let textHeight = font.capHeight
            let origin = CGPoint(x: 6, y: (height - textHeight) / 2 - (font.ascender - font.capHeight))
            (trimmed as NSString).draw(at: origin, withAttributes: attributes)
            _ = context
        }
        flairCache.store(key, image)
        return image.withRenderingMode(.alwaysOriginal)
    }

    // Texture allocates cells on several threads at once, so the caches need a
    // lock: a plain static dictionary mutated from two threads crashes.
    private static let flairCache = LockedImageCache()

    // MARK: - Vote button

    /// The vote button in a large cell: 32x32. A neutral post shows the bare
    /// arrow glyph in grey; a voted post shows a filled rounded square in the
    /// brand vote colour with a white arrow. Measured: radius 8, arrow ~18pt.
    static func voteButton(up: Bool, voted: Bool, traits: UITraitCollection) -> UIImage? {
        let scale = traits.displayScale > 0 ? traits.displayScale : 3
        let glyphName = up ? "option-upvote" : "option-downvote"
        guard let glyph = ApolloAssets.image(named: glyphName) else { return nil }

        let fill: UIColor? = voted ? (up ? ApolloPalette.upvote : ApolloPalette.downvote) : nil
        let tint: UIColor = voted ? .white : ApolloPalette.iconGrey
        let key = "vote|\(up)|\(voted)|\(tint.hashValue)|\(scale)"
        if let cached = voteCache.value(key) { return cached }

        let size = CGSize(width: 32, height: 32)
        let arrowHeight: CGFloat = 18
        let arrowWidth = glyph.size.width / max(glyph.size.height, 1) * arrowHeight
        let arrowRect = CGRect(x: (size.width - arrowWidth) / 2,
                               y: (size.height - arrowHeight) / 2,
                               width: arrowWidth, height: arrowHeight)

        let image = UIGraphicsImageRenderer(size: size, format: rendererFormat(scale: scale)).image { context in
            if let fill = fill {
                fill.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8).fill()
            }
            _ = context
            glyph.withTintColor(tint, renderingMode: .alwaysOriginal)
                .draw(in: arrowRect, blendMode: .normal, alpha: 1)
        }
        voteCache.store(key, image)
        return image.withRenderingMode(.alwaysOriginal)
    }

    private static let voteCache = LockedImageCache()

    // MARK: - Shared helpers

    /// Texture lays out off the main thread, so always render at the node's
    /// own display scale rather than whatever UIScreen currently reports.
    private static func rendererFormat(scale: CGFloat) -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return format
    }

    /// A template rendition of one of Apollo's catalog glyphs, sized to a
    /// height and tinted. Used for the small info-row glyphs.
    static func glyph(named name: String, height: CGFloat, tint: UIColor) -> UIImage? {
        guard let glyph = ApolloAssets.image(named: name) else { return nil }
        let width = glyph.size.width / max(glyph.size.height, 1) * height
        return glyph.withTintColor(tint, renderingMode: .alwaysOriginal)
            .resized(to: CGSize(width: width, height: height))
    }
}

/// A tiny thread-safe image cache: node blocks run off the main thread and in
/// parallel, so every write has to be serialised.
private final class LockedImageCache {
    private let lock = NSLock()
    private var storage: [String: UIImage] = [:]

    func value(_ key: String) -> UIImage? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage[key]
    }

    func store(_ key: String, _ image: UIImage) {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.storage[key] = image
    }
}

private extension UIImage {
    /// Scale an original-mode image without re-tinting it.
    func resized(to size: CGSize) -> UIImage {
        guard self.size != size else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(self.renderingMode)
    }
}
