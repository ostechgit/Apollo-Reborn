import UIKit
import AsyncDisplayKit

// RichMediaNode - the media strip of a post: a full-bleed image, a gallery, a
// video preview, or an external link's preview card.
// Reconstructed from apollo-base 1.15.11 binary analysis (Apollo.RichMediaNode)
// and measured off 3x screenshots of the original.
//
// The original decides how to draw a post from Reddit's own hints: a post that
// points at Reddit-hosted media (image, gallery, v.redd.it video) fills the
// whole cell width with no insets and no rounded corners, while a post that
// points at another site gets a small rounded preview card inset 16pt, drawn
// by LinkButtonNode. That distinction is visible in the original's feed: the
// r/pics meme is edge to edge, the BBC article is a card.
//
// The original also plays video inline, handles crossposts, albums and the
// NSFW/spoiler veil; none of that is wired up here yet.

class RichMediaNode: ASControlNode, UIGestureRecognizerDelegate {

    enum Presentation {
        /// Reddit-hosted media: edge to edge, aspect preserved.
        case fullBleed
        /// Another site's link: the inset preview card.
        case linkCard
    }

    let link: RDKLink
    let presentation: Presentation
    /// Called when the media is tapped; the screen decides what to open.
    var onTapped: (() -> Void)?

    private let imageNode = ASNetworkImageNode()
    private let playNode = ASImageNode()
    /// NSFW and spoiler posts are blurred behind a centred badge until the
    /// reader taps. The badge assets are the original's `obscured-nsfw` /
    /// `obscured-spoiler`; they are small glyphs, NOT a full-frame overlay, so
    /// the blur is what actually hides the picture.
    /// A plain node, not a `UIVisualEffectView` inside a `viewBlock`: Texture
    /// lays subnodes out on a background thread, and UIKit views created that way
    /// assert and can wedge the table (the same trap as the old comment menu
    /// button). A dark scrim hides the picture just as effectively.
    private let blurNode = ASDisplayNode()
    private let veilNode = ASImageNode()
    /// "1/4" badge for a gallery, which the original draws over the image.
    private let galleryCountNode = ASTextNode()
    /// Galleries page in place. A pan recogniser swaps the image rather than
    /// hosting a scroll view, which keeps every UIKit layout on the main thread.
    private var galleryIndex = 0
    private var galleryURLs: [URL] = []
    private var isVeiled: Bool
    private let cardNode: LinkButtonNode?

    /// Portrait images are cropped rather than allowed to run past this many
    /// cells-worth of height (the original caps feed media the same way).
    private let maximumAspectRatio: CGFloat = 1.25

    init?(link: RDKLink, isShownInCommentsHeader: Bool = false) {
        guard link.hasPreviewImage else { return nil }

        self.link = link
        // post_hint is Reddit's own statement about where the link points:
        // "image", "hosted:video" and gallery posts are Reddit media, "link"
        // is somebody else's page.
        // YouTube and Streamable are played in-app, so they get the media
        // treatment (preview + play badge) rather than an article card.
        let isExternalVideo = ExternalVideoSource(url: link.url.flatMap(URL.init(string:))) != nil
        let isRedditMedia = link.isImageLink || link.isVideo || link.isGallery || isExternalVideo
        self.presentation = isRedditMedia ? .fullBleed : .linkCard
        self.cardNode = isRedditMedia ? nil : LinkButtonNode(link: link)
        self.isVeiled = link.isNSFW || link.isSpoiler
        super.init()
        self.automaticallyManagesSubnodes = true
        self.cardNode?.isUserInteractionEnabled = false

        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.clipsToBounds = true
        self.imageNode.placeholderColor = .secondarySystemBackground
        self.imageNode.placeholderEnabled = true
        // The node itself is the tap target, so no child may swallow the touch.
        self.imageNode.isUserInteractionEnabled = false
        self.blurNode.backgroundColor = UIColor(white: 0, alpha: 0.82)
        self.blurNode.isUserInteractionEnabled = false
        if link.isGallery, let images = link.galleryImages {
            self.galleryURLs = images.compactMap { $0.url.flatMap(URL.init(string:)) }
        }
        if link.isGallery, link.galleryItemCount > 1 {
            self.galleryCountNode.attributedText = NSAttributedString(string: "1/\(link.galleryItemCount)", attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: UIColor.white,
            ])
            self.galleryCountNode.backgroundColor = UIColor(white: 0, alpha: 0.55)
            self.galleryCountNode.cornerRadius = 11
            self.galleryCountNode.textContainerInset = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        }
        self.veilNode.contentMode = .center
        self.veilNode.isUserInteractionEnabled = false
        // The catalog rendition is a black diamond with a white "!", so it must
        // not be template-tinted.
        if let badge = ApolloAssets.originalImage(named: link.isNSFW ? "obscured-nsfw" : "obscured-spoiler") {
            self.veilNode.image = badge
            self.veilNode.style.preferredSize = badge.size
        }

        self.playNode.image = ApolloAssets.originalImage(named: "video-playhead-large")
        self.playNode.style.preferredSize = CGSize(width: 48, height: 48)
        self.playNode.isUserInteractionEnabled = false

        // The whole media area is one tap target: the picture, the link card
        // and the gallery all open the same thing.
        self.addTarget(self, action: #selector(mediaTapped), forControlEvents: .touchUpInside)
    }

    // MARK: - Layout

    override func layoutSpecThatFits(_ constrainedSize: ASSizeRange) -> ASLayoutSpec {
        switch self.presentation {
        case .linkCard:
            guard let cardNode = self.cardNode else { return ASLayoutSpec() }
            // Measured: the card sits 16pt below the title's last line, inset
            // 16pt from the cell's edges, and draws its own footer padding.
            return ASInsetLayoutSpec(insets: UIEdgeInsets(top: 16, left: 16, bottom: 0, right: 16),
                                     child: cardNode)

        case .fullBleed:
            let width = max(constrainedSize.max.width, 1)
            let scale = self.apolloDrawingTraits.displayScale
            let item = self.link.previewImage(forWidth: width, scale: scale)
            let url = item?.url.flatMap(URL.init(string:))
            if self.imageNode.url != url {
                self.imageNode.url = url
            }

            let natural = CGFloat(item?.height ?? 0) / CGFloat(max(item?.width ?? 0, 1))
            let ratio = min(max(natural, 0.2), self.maximumAspectRatio)
            var media: ASLayoutSpec = ASRatioLayoutSpec(ratio: ratio, child: self.imageNode)
            if self.link.isGallery, self.link.galleryItemCount > 1 {
                // Anchor the badge to the bottom-right; an infinite inset is not
                // a valid layout and wedges measuring.
                media = ASOverlayLayoutSpec(child: media,
                                            overlay: ASInsetLayoutSpec(insets: UIEdgeInsets(top: 0, left: 0,
                                                                                            bottom: 10, right: 10),
                                                                       child: ASRelativeLayoutSpec(
                                                                        horizontalPosition: .end,
                                                                        verticalPosition: .end,
                                                                        sizingOption: .minimumSize,
                                                                        child: self.galleryCountNode)))
            }
            if self.isVeiled {
                // Blur the picture, then centre the badge over it.
                media = ASOverlayLayoutSpec(child: media, overlay: self.blurNode)
                media = ASOverlayLayoutSpec(child: media,
                                            overlay: ASCenterLayoutSpec(centeringOptions: .XY,
                                                                        sizingOptions: [],
                                                                        child: self.veilNode))
            }

            if self.link.isVideo || ExternalVideoSource(url: self.link.url.flatMap(URL.init(string:))) != nil {
                media = ASOverlayLayoutSpec(child: media,
                                            overlay: ASCenterLayoutSpec(centeringOptions: .XY,
                                                                        sizingOptions: [],
                                                                        child: self.playNode))
            }
            return media
        }
    }

    // MARK: - Actions

    @objc private func mediaTapped() {
        // First tap lifts an NSFW/spoiler veil; the reader has to tap again to
        // open the media, which is how the original treats obscured posts.
        if self.isVeiled {
            self.isVeiled = false
            self.setNeedsLayout()
            self.transitionLayout(withAnimation: true, shouldMeasureAsync: false)
            return
        }
        self.onTapped?()
    }
}
