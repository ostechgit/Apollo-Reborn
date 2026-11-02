import UIKit

// SlideGesturePan - the horizontal drag that fires a configurable swipe action.
//
// Apollo's feed, comment list and profile lists all use the same gesture model
// (`SlideGestureBuilder` in the binary): a horizontal pan that resolves to one of
// four `SlideGesturePoint` slots depending on direction and how far it travelled.
// Vertical drags must stay with the enclosing scroll view, so this recogniser
// only begins for a predominantly horizontal movement and never runs
// simultaneously with another recogniser.
//
// The owner keeps a strong reference to the instance; a gesture recogniser's
// target is held weakly, so a local would be released immediately.

final class SlideGesturePan: NSObject, UIGestureRecognizerDelegate {

    private let onSlide: (SlideGesturePoint) -> Void
    private let context: SlideGestureContext

    init(context: SlideGestureContext, onSlide: @escaping (SlideGesturePoint) -> Void) {
        self.context = context
        self.onSlide = onSlide
        super.init()
    }

    func attach(to view: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(SlideGesturePan.panned(_:)))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
    }

    @objc private func panned(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.state == .ended, let view = recognizer.view else { return }
        let translation = recognizer.translation(in: view)
        guard abs(translation.x) > abs(translation.y) else { return }
        let width = max(view.bounds.width, 1)
        let fraction = abs(translation.x) / width
        guard fraction >= SlideGestureSettings.minimumSwipeFraction else { return }

        let leftward = translation.x < 0
        if leftward ? SlideGestureSettings.leftSwipesDisabled : SlideGestureSettings.rightSwipesDisabled {
            return
        }
        let isLong = fraction >= SlideGestureSettings.longSwipeThreshold
        let point: SlideGesturePoint
        switch (leftward, isLong) {
        case (true, false): point = .firstLeft
        case (true, true): point = .secondLeft
        case (false, false): point = .firstRight
        case (false, true): point = .secondRight
        }
        self.onSlide(point)
    }

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
