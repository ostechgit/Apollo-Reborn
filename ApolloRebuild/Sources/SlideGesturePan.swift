import UIKit

// SlideGesturePan - the horizontal drag that fires a configurable swipe action,
// and the reveal it draws while you drag.
//
// Reconstructed from `SlideGestureBuilder` in the base binary:
//
//   * `method_22` (gesture began) creates `gestureDisplayView` — a plain view
//     inserted *below* the sliding view, spanning the card — and
//     `gestureDisplayIcon` inside it.
//   * `method_26` (changed) translates the sliding view by `0.85 * translation.x`
//     and sets the panel's colour and the icon's image/alpha. The icon fades in
//     over 58pt (`min(|translation| / 58, 1)`), sits 12pt from the revealed
//     edge and is 34pt wide.
//   * `method_21.helper_1004101d0` (ended) wraps the collapse in
//     `animateWithDuration:delay:usingSpringWithDamping:initialSpringVelocity:`
//     with damping 1.0 and velocity 2.0, then removes both views.
//
// So the effect is a full-height coloured panel revealed from the side the row
// is pulled towards, its width following the drag, with the action's icon near
// the outer edge. Stock also slides the cell content at 0.85x; this renders the
// panel over the content instead, because Texture owns the cell's subviews and
// translating them per frame is not safe across reuse. The revealed width, the
// icon geometry, the fade and the spring match.
//
// Vertical drags must stay with the enclosing scroll view, so the recogniser
// only begins for a predominantly horizontal movement and never runs
// simultaneously with another recogniser.

final class SlideGesturePan: NSObject, UIGestureRecognizerDelegate {

    private let onSlide: (SlideGesturePoint) -> Void
    private let context: SlideGestureContext

    private weak var host: UIView?
    private let panel = UIView()
    private let iconView = UIImageView()

    /// Read once when the gesture begins; defaults reads per frame would be
    /// wasteful during a drag.
    private var actions: [SlideGestureAction] = []
    private var shownPoint: SlideGesturePoint?

    // Geometry recovered from `method_26`.
    private static let contentSlideRate: CGFloat = 0.85
    private static let iconSize: CGFloat = 34
    private static let iconEdgeInset: CGFloat = 12
    private static let iconFadeDistance: CGFloat = 58

    init(context: SlideGestureContext, onSlide: @escaping (SlideGesturePoint) -> Void) {
        self.context = context
        self.onSlide = onSlide
        super.init()
    }

    func attach(to view: UIView) {
        self.host = view

        self.panel.clipsToBounds = true
        self.panel.isUserInteractionEnabled = false
        self.panel.isHidden = true
        view.addSubview(self.panel)

        self.iconView.contentMode = .scaleAspectFit
        self.iconView.tintColor = .white
        self.iconView.frame = CGRect(x: 0, y: 0,
                                     width: Self.iconSize, height: Self.iconSize)
        self.panel.addSubview(self.iconView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(SlideGesturePan.panned(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    // MARK: - Gesture

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view)

        switch recognizer.state {
        case .began:
            self.actions = SlideGestureSettings.actions(for: self.context)
            self.shownPoint = nil

        case .changed:
            guard abs(translation.x) > abs(translation.y) else {
                self.collapsePanel(in: view, animated: false)
                return
            }
            let leftward = translation.x < 0
            if leftward ? SlideGestureSettings.leftSwipesDisabled : SlideGestureSettings.rightSwipesDisabled {
                self.collapsePanel(in: view, animated: false)
                return
            }
            let fraction = abs(translation.x) / max(view.bounds.width, 1)
            let isLong = fraction >= SlideGestureSettings.longSwipeThreshold
            let point: SlideGesturePoint = leftward
                ? (isLong ? .secondLeft : .firstLeft)
                : (isLong ? .secondRight : .firstRight)
            self.showPanel(for: point, leftward: leftward, translation: translation, in: view)

        case .ended:
            let fraction = abs(translation.x) / max(view.bounds.width, 1)
            let leftward = translation.x < 0
            let valid = abs(translation.x) > abs(translation.y)
                && fraction >= SlideGestureSettings.minimumSwipeFraction
            self.collapsePanel(in: view, animated: true)
            guard valid else { return }
            if leftward ? SlideGestureSettings.leftSwipesDisabled : SlideGestureSettings.rightSwipesDisabled {
                return
            }
            let isLong = fraction >= SlideGestureSettings.longSwipeThreshold
            let point: SlideGesturePoint = leftward
                ? (isLong ? .secondLeft : .firstLeft)
                : (isLong ? .secondRight : .firstRight)
            self.onSlide(point)

        default:
            self.collapsePanel(in: view, animated: true)
        }
    }

    // MARK: - Panel

    private func showPanel(for point: SlideGesturePoint, leftward: Bool,
                           translation: CGPoint, in view: UIView) {
        let index = point.rawValue
        guard index < self.actions.count else { return }
        let action = self.actions[index]

        let width = view.bounds.width
        let height = view.bounds.height
        // The panel is revealed exactly as far as the content would have moved.
        let revealed = min(abs(translation.x) * Self.contentSlideRate, width)

        self.panel.isHidden = false
        self.panel.backgroundColor = action.indicatorColor
        self.panel.frame = leftward
            ? CGRect(x: width - revealed, y: 0, width: revealed, height: height)
            : CGRect(x: 0, y: 0, width: revealed, height: height)

        self.iconView.frame = CGRect(
            x: leftward ? revealed - Self.iconEdgeInset - Self.iconSize : Self.iconEdgeInset,
            y: (height - Self.iconSize) / 2,
            width: Self.iconSize, height: Self.iconSize)
        // `min(|translation| / 58, 1)` in the original.
        self.iconView.alpha = min(abs(translation.x) / Self.iconFadeDistance, 1)

        if self.shownPoint != point {
            self.shownPoint = point
            // Stock ships a two-state glyph per action: `-hollow` for the short
            // slot and `-solid` once the drag reaches the long-slot threshold.
            // A few actions only have a solid rendition, hence the fallback.
            let suffix = point.isLong ? "solid" : "hollow"
            let base = "slide-\(action.slideAssetBase)"
            self.iconView.image = ApolloAssets.image(named: "\(base)-\(suffix)")
                ?? ApolloAssets.image(named: "\(base)-solid")
        }
    }

    /// Collapses the reveal. Stock animates this with damping 1.0 / velocity 2.0.
    private func collapsePanel(in view: UIView, animated: Bool) {
        self.shownPoint = nil
        guard !self.panel.isHidden else { return }
        let finish = {
            self.panel.isHidden = true
            self.iconView.alpha = 0
            self.panel.frame = .zero
        }
        guard animated else {
            finish()
            return
        }
        UIView.animate(withDuration: 0.2, delay: 0,
                       usingSpringWithDamping: 1.0, initialSpringVelocity: 2.0,
                       options: [.curveEaseOut], animations: {
            self.panel.alpha = 0
        }, completion: { _ in
            self.panel.alpha = 1
            finish()
        })
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
        let velocity = pan.velocity(in: view)
        return abs(velocity.x) > abs(velocity.y)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }
}

extension SlideGestureAction {
    /// Base name of the action's `slide-*` asset pair in the app's catalog.
    var slideAssetBase: String {
        switch self {
        case .upvote: return "upvote"
        case .unupvote: return "unupvote"
        case .downvote: return "downvote"
        case .undownvote: return "undownvote"
        case .save: return "save"
        case .unsave: return "unsave"
        case .collapse: return "collapse"
        case .collapseRoot: return "collapse-root"
        case .reply: return "reply"
        case .toggleRead, .markRead: return "read"
        case .markUnread: return "unread"
        case .post: return "post"
        case .hide: return "hide"
        case .hideAbove: return "hide-above"
        case .selectMode: return "select-mode"
        case .parentComment: return "parent-comment"
        case .moreOptions: return "more"
        case .share: return "share"
        case .author: return "author"
        case .subreddit: return "subreddit"
        }
    }

    /// Background colour of the reveal panel.
    ///
    /// Recovered from `SlideGestureBuilder.method_26.helper_10040cb4c`, which
    /// builds a six-digit hex string per action and hands it to
    /// `UIColor(hex:)`. These are the values its live (argument-zero) arms
    /// return, so they are exact rather than approximated.
    var indicatorColor: UIColor {
        switch self {
        case .upvote, .unupvote:               return UIColor(apolloHex: "FF6C00")
        case .downvote, .undownvote:           return UIColor(apolloHex: "565FE3")
        case .save, .unsave:                   return UIColor(apolloHex: "00AC37")
        case .collapse, .collapseRoot:         return UIColor(apolloHex: "0082F7")
        case .reply:                           return UIColor(apolloHex: "23B5FF")
        case .toggleRead, .markRead, .markUnread, .selectMode:
            return UIColor(apolloHex: "0D6BE9")
        case .post, .hide, .hideAbove:         return UIColor(apolloHex: "8348F5")
        case .parentComment:                   return UIColor(apolloHex: "3BD672")
        case .moreOptions:                     return UIColor(apolloHex: "C7CCD1")
        case .share:                           return UIColor(apolloHex: "00C0FF")
        case .author:                          return UIColor(apolloHex: "2E6FBA")
        case .subreddit:                       return UIColor(apolloHex: "FF6633")
        }
    }
}

extension UIColor {
    /// `UIColor(hex:)` as Apollo defines it: six hex digits, no leading hash.
    convenience init(apolloHex hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }
}
