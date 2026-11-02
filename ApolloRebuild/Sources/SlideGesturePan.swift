import UIKit

// SlideGesturePan - the horizontal drag that fires a configurable swipe action,
// plus the badge stock shows while you drag.
//
// Apollo's model (`SlideGestureBuilder` in the binary) tracks a
// `gestureDisplayView` with a `gestureDisplayIcon` at `iconDistanceFromCellEdge`,
// switches the icon when the drag passes `firstThreshold` / `secondThreshold`,
// and animates the swap (`animatingIcon`). This is that behaviour: the badge
// appears on the side the row is being pulled towards, shows the action's icon
// and colour, and swaps to the long-swipe action's icon once you cross the
// threshold.
//
// Vertical drags must stay with the enclosing scroll view, so the recogniser
// only begins for a predominantly horizontal movement and never runs
// simultaneously with another recogniser.

final class SlideGesturePan: NSObject, UIGestureRecognizerDelegate {

    private let onSlide: (SlideGesturePoint) -> Void
    private let context: SlideGestureContext

    private weak var host: UIView?
    private let badge = UIView()
    private let iconView = UIImageView()

    /// Read once when the gesture begins; defaults reads per frame would be
    /// wasteful during a drag.
    private var actions: [SlideGestureAction] = []
    private var shownPoint: SlideGesturePoint?

    private static let badgeSize: CGFloat = 36
    /// `iconDistanceFromCellEdge` in the original; the exact value was not
    /// recovered, this is the spacing used here.
    private static let edgeInset: CGFloat = 20

    init(context: SlideGestureContext, onSlide: @escaping (SlideGesturePoint) -> Void) {
        self.context = context
        self.onSlide = onSlide
        super.init()
    }

    func attach(to view: UIView) {
        self.host = view

        self.badge.isUserInteractionEnabled = false
        self.badge.layer.cornerRadius = Self.badgeSize / 2
        self.badge.clipsToBounds = true
        self.badge.alpha = 0
        self.badge.subviews.forEach { $0.removeFromSuperview() }

        self.iconView.frame = self.badge.bounds
        self.iconView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.iconView.contentMode = .scaleAspectFit
        self.iconView.tintColor = .white
        self.badge.addSubview(self.iconView)
        view.addSubview(self.badge)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(SlideGesturePan.panned(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    // MARK: - Gesture

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        guard let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view)
        let width = max(view.bounds.width, 1)

        switch recognizer.state {
        case .began:
            self.actions = SlideGestureSettings.actions(for: self.context)
            self.shownPoint = nil

        case .changed:
            guard abs(translation.x) > abs(translation.y) else {
                self.hideBadge()
                return
            }
            let fraction = min(abs(translation.x) / width, 1)
            guard fraction > 0.02 else {
                self.hideBadge()
                return
            }
            let leftward = translation.x < 0
            if leftward ? SlideGestureSettings.leftSwipesDisabled : SlideGestureSettings.rightSwipesDisabled {
                self.hideBadge()
                return
            }
            let isLong = fraction >= SlideGestureSettings.longSwipeThreshold
            let point: SlideGesturePoint = leftward
                ? (isLong ? .secondLeft : .firstLeft)
                : (isLong ? .secondRight : .firstRight)
            self.showBadge(for: point, leftward: leftward, fraction: fraction, in: view)

        case .ended:
            let fraction = abs(translation.x) / width
            let leftward = translation.x < 0
            let valid = abs(translation.x) > abs(translation.y)
                && fraction >= SlideGestureSettings.minimumSwipeFraction
            self.hideBadge()
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
            self.hideBadge()
        }
    }

    // MARK: - Badge

    private func showBadge(for point: SlideGesturePoint, leftward: Bool,
                           fraction: CGFloat, in view: UIView) {
        let index = point.rawValue
        guard index < self.actions.count else { return }
        let action = self.actions[index]
        let width = view.bounds.width

        let x = leftward
            ? width - Self.badgeSize - Self.edgeInset
            : Self.edgeInset
        let y = (view.bounds.height - Self.badgeSize) / 2

        if self.shownPoint != point {
            let wasShowing = self.shownPoint != nil
            self.shownPoint = point
            self.badge.backgroundColor = action.indicatorColor
            // Stock ships a two-state glyph per action: `-hollow` for the short
            // slot and `-solid` once the drag reaches the long-slot threshold.
            // A few actions only have a solid rendition, hence the fallback.
            let suffix = point.isLong ? "solid" : "hollow"
            let base = "slide-\(action.slideAssetBase)"
            let image = ApolloAssets.image(named: "\(base)-\(suffix)")
                ?? ApolloAssets.image(named: "\(base)-solid")
            self.iconView.image = image
            if wasShowing {
                // The original animates the icon swap when the slot changes.
                let swap = CATransition()
                swap.duration = 0.15
                swap.type = .fade
                self.iconView.layer.add(swap, forKey: "iconSwap")
            }
        }

        self.badge.frame = CGRect(x: x, y: y, width: Self.badgeSize, height: Self.badgeSize)

        // Grow in as the drag approaches the (short) threshold, the way stock's
        // icon scales up rather than snapping into place.
        let progress = min(fraction / max(SlideGestureSettings.longSwipeThreshold, 0.01), 1)
        let scale = 0.72 + 0.28 * progress
        self.badge.transform = CGAffineTransform(scaleX: scale, y: scale)
        self.badge.alpha = min(1, fraction / 0.12)
    }

    private func hideBadge() {
        self.shownPoint = nil
        if self.badge.alpha != 0 {
            self.badge.alpha = 0
            self.badge.transform = .identity
        }
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
        case .hideAbove: return "hide-above"
        case .selectMode: return "select-mode"
        case .parentComment: return "parent-comment"
        case .moreOptions: return "more"
        }
    }

    /// Colour of the swipe badge for this action.
    ///
    /// Upvote / downvote use Apollo's fixed brand colours (recovered from the
    /// vote pill). The rest are conventional choices: their exact colours were
    /// not recovered from the binary.
    var indicatorColor: UIColor {
        switch self {
        case .upvote, .unupvote:
            return ApolloPalette.upvote
        case .downvote, .undownvote:
            return ApolloPalette.downvote
        case .save, .unsave:
            return .systemPurple
        case .reply:
            return .systemBlue
        case .collapse, .collapseRoot:
            return .systemTeal
        case .hideAbove:
            return .systemGray
        case .moreOptions:
            return ApolloPalette.iconGrey
        case .selectMode:
            return .systemGreen
        default:
            return .systemGray
        }
    }
}
