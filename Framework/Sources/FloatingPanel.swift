//
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import UIKit
import UIKit.UIGestureRecognizerSubclass // For Xcode 9.4.1

///
/// FloatingPanel presentation model
///
class FloatingPanel: NSObject, UIGestureRecognizerDelegate {
    // MUST be a weak reference to prevent UI freeze on the presentation modally
    weak var viewcontroller: FloatingPanelController?

    let surfaceView: FloatingPanelSurfaceView
    let backdropView: FloatingPanelBackdropView
    let layoutAdapter: FloatingPanelLayoutAdapter
    let behaviorAdapter: FloatingPanelBehaviorAdapter

    weak var scrollView: UIScrollView? {
        didSet {
            oldValue?.panGestureRecognizer.removeTarget(self, action: nil)
            scrollView?.panGestureRecognizer.addTarget(self, action: #selector(handle(panGesture:)))
        }
    }

    private(set) var state: FloatingPanelState = .hidden {
        didSet {
            if let vc = viewcontroller {
                vc.delegate?.floatingPanelDidChangePosition?(vc)
            }
        }
    }

    private var surfaceEdgeY: CGFloat {
        return edgeY(frame: surfaceView.presentationFrame)
    }

    private func edgeY(frame: CGRect) -> CGFloat {
        return layoutAdapter.edgeY(frame)
    }

    let panGestureRecognizer: FloatingPanelPanGestureRecognizer
    var isRemovalInteractionEnabled: Bool = false

    fileprivate var animator: UIViewPropertyAnimator?

    private var initialFrame: CGRect = .zero
    private var initialTranslationY: CGFloat = 0
    private var initialLocation: CGPoint = .nan

    var interactionInProgress: Bool = false
    var isDecelerating: Bool = false

    // Scroll handling
    private var initialScrollOffset: CGPoint = .zero
    private var stopScrollDeceleration: Bool = false
    private var scrollBouncable = false
    private var scrollIndictorVisible = false

    // MARK: - Interface

    init(_ vc: FloatingPanelController, layout: FloatingPanelLayout, behavior: FloatingPanelBehavior) {
        viewcontroller = vc

        surfaceView = FloatingPanelSurfaceView()
        surfaceView.backgroundColor = .white

        backdropView = FloatingPanelBackdropView()
        backdropView.backgroundColor = .black
        backdropView.alpha = 0.0

        self.layoutAdapter = FloatingPanelLayoutAdapter(vc: vc,
                                                        surfaceView: surfaceView,
                                                        backdropView: backdropView,
                                                        layout: layout)
        self.behaviorAdapter = FloatingPanelBehaviorAdapter(vc: vc, behavior: behavior)

        panGestureRecognizer = FloatingPanelPanGestureRecognizer()

        if #available(iOS 11.0, *) {
            panGestureRecognizer.name = "FloatingPanelSurface"
        }

        super.init()

        panGestureRecognizer.floatingPanel = self

        surfaceView.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.addTarget(self, action: #selector(handle(panGesture:)))
        panGestureRecognizer.delegate = self

        // Set tap-to-dismiss in the backdrop view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBackdrop(tapGesture:)))
        tapGesture.isEnabled = false
        backdropView.dismissalTapGestureRecognizer = tapGesture
        backdropView.addGestureRecognizer(tapGesture)
    }

    func move(to: FloatingPanelState, animated: Bool, completion: (() -> Void)? = nil) {
        move(from: state, to: to, animated: animated, completion: completion)
    }

    private func move(from: FloatingPanelState, to: FloatingPanelState, animated: Bool, completion: (() -> Void)? = nil) {
        assert(layoutAdapter.isValid(to), "Can't move to '\(to)' position because it's not valid in the layout")
        guard let vc = viewcontroller else {
            completion?()
            return
        }
        if state != layoutAdapter.topMostState {
            lockScrollView()
        }
        tearDownActiveInteraction()

        if animated {
            let animator: UIViewPropertyAnimator
            switch (from, to) {
            case (.hidden, let to):
                animator = behaviorAdapter.behavior.addAnimator?(vc, to: to) ?? FloatingPanelDefaultBehavior().addAnimator(vc, to: to)
            case (let from, .hidden):
                animator = behaviorAdapter.behavior.removeAnimator?(vc, from: from) ?? FloatingPanelDefaultBehavior().removeAnimator(vc, from: from)
            case (let from, let to):
                animator = behaviorAdapter.behavior.moveAnimator?(vc, from: from, to: to) ?? FloatingPanelDefaultBehavior().moveAnimator(vc, from: from, to: to)
            }

            animator.addAnimations { [weak self] in
                guard let `self` = self else { return }

                self.state = to
                self.updateLayout(to: to)
            }
            animator.addCompletion { [weak self] _ in
                guard let `self` = self else { return }
                self.animator = nil
                if self.state == self.layoutAdapter.topMostState {
                    self.unlockScrollView()
                } else {
                    self.lockScrollView()
                }
                completion?()
            }
            self.animator = animator
            animator.startAnimation()
        } else {
            self.state = to
            self.updateLayout(to: to)
            if self.state == self.layoutAdapter.topMostState {
                self.unlockScrollView()
            } else {
                self.lockScrollView()
            }
            completion?()
        }
    }

    // MARK: - Layout update

    private func updateLayout(to target: FloatingPanelState) {
        self.layoutAdapter.activateFixedLayout()
        self.layoutAdapter.activateInteractiveLayout(of: target)
    }

    func getBackdropAlpha(at currentY: CGFloat, with translation: CGPoint) -> CGFloat {
        let forwardY = (translation.y >= 0)
        let segment = layoutAdapter.segument(at: currentY, forward: forwardY)
        let lowerPos = segment.lower ?? layoutAdapter.topMostState
        let upperPos = segment.upper ?? layoutAdapter.bottomMostState

        let pre = forwardY ? lowerPos : upperPos
        let next = forwardY ? upperPos : lowerPos

        let nextY = layoutAdapter.positionY(for: next)
        let preY = layoutAdapter.positionY(for: pre)

        let nextAlpha = layoutAdapter.backdropAlpha(for: next)
        let preAlpha = layoutAdapter.backdropAlpha(for: pre)

        if preY == nextY {
            return preAlpha
        } else {
            return preAlpha + max(min(1.0, 1.0 - (nextY - currentY) / (nextY - preY) ), 0.0) * (nextAlpha - preAlpha)
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else { return false }

        /* log.debug("shouldRecognizeSimultaneouslyWith", otherGestureRecognizer) */

        if let vc = viewcontroller,
            vc.delegate?.floatingPanel?(vc, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false {
            return true
        }

        switch otherGestureRecognizer {
        case is UIPanGestureRecognizer,
             is UISwipeGestureRecognizer,
             is UIRotationGestureRecognizer,
             is UIScreenEdgePanGestureRecognizer,
             is UIPinchGestureRecognizer:
            // all gestures of the tracking scroll view should be recognized in parallel
            // and handle them in self.handle(panGesture:)
            return scrollView?.gestureRecognizers?.contains(otherGestureRecognizer) ?? false
        default:
            // Should recognize tap/long press gestures in parallel when the surface view is at an anchor position.
            return surfaceEdgeY == layoutAdapter.positionY(for: state)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else { return false }
        /* log.debug("shouldBeRequiredToFailBy", otherGestureRecognizer) */
        return false
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGestureRecognizer else { return false }

        /* log.debug("shouldRequireFailureOf", otherGestureRecognizer) */

        // Should begin the pan gesture without waiting for the tracking scroll view's gestures.
        // `scrollView.gestureRecognizers` can contains the following gestures
        // * UIScrollViewDelayedTouchesBeganGestureRecognizer
        // * UIScrollViewPanGestureRecognizer (scrollView.panGestureRecognizer)
        // * _UIDragAutoScrollGestureRecognizer
        // * _UISwipeActionPanGestureRecognizer
        // * UISwipeDismissalGestureRecognizer
        if let scrollView = scrollView {
            // On short contents scroll, `_UISwipeActionPanGestureRecognizer` blocks
            // the panel's pan gesture if not returns false
            if let scrollGestureRecognizers = scrollView.gestureRecognizers,
                scrollGestureRecognizers.contains(otherGestureRecognizer) {
                return false
            }
        }

        if let vc = viewcontroller,
            vc.delegate?.floatingPanel?(vc, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer) ?? false {
            return false
        }

        switch otherGestureRecognizer {
        case is UIPanGestureRecognizer,
             is UISwipeGestureRecognizer,
             is UIRotationGestureRecognizer,
             is UIScreenEdgePanGestureRecognizer,
             is UIPinchGestureRecognizer:
            // Do not begin the pan gesture until these gestures fail
            return true
        default:
            // Should begin the pan gesture without waiting tap/long press gestures fail
            return false
        }
    }

    var grabberAreaFrame: CGRect {
        return surfaceView.grabberAreaFrame
    }

    // MARK: - Gesture handling

    @objc func handleBackdrop(tapGesture: UITapGestureRecognizer) {
        viewcontroller?.dismiss(animated: true) { [weak self] in
            guard let vc = self?.viewcontroller else { return }
            vc.delegate?.floatingPanelDidEndRemove?(vc)
        }
    }

    @objc func handle(panGesture: UIPanGestureRecognizer) {
        let velocity = panGesture.velocity(in: panGesture.view)

        switch panGesture {
        case scrollView?.panGestureRecognizer:
            guard let scrollView = scrollView else { return }

            let location = panGesture.location(in: surfaceView)

            let belowEdgeMost = 0 > layoutAdapter.offsetFromEdgeMost
            let offset = scrollView.contentOffset.y - scrollView.contentOffsetZero.y
            let offsetMax = max(scrollView.contentSize.height - scrollView.bounds.height, 0.0)

            log.debug("scroll gesture(\(state):\(panGesture.state)) --",
                "belowTop = \(belowEdgeMost),",
                "interactionInProgress = \(interactionInProgress),",
                "scroll offset = \(offset),",
                "location = \(location.y), velocity = \(velocity.y)")

            if belowEdgeMost {
                // Scroll offset pinning
                if state == layoutAdapter.edgeMostState {
                    if interactionInProgress {
                        log.debug("settle offset --", initialScrollOffset.y)
                        scrollView.setContentOffset(initialScrollOffset, animated: false)
                    } else {
                        if grabberAreaFrame.contains(location) {
                            // Preserve the current content offset in moving from full.
                            scrollView.setContentOffset(initialScrollOffset, animated: false)
                        }
                    }
                } else {
                    scrollView.setContentOffset(initialScrollOffset, animated: false)
                }

                // Hide a scroll indicator at the non-top in dragging.
                if interactionInProgress {
                    lockScrollView()
                } else {
                    if state == layoutAdapter.edgeMostState, self.animator == nil {
                        switch layoutAdapter.layout.interactiveEdge {
                        case .top where offset > 0 && velocity.y < 0:
                            unlockScrollView()
                        case .bottom where offset < offsetMax && velocity.y > 0:
                            unlockScrollView()
                        default:
                            break
                        }
                    }
                }
            } else {
                if interactionInProgress {
                    // Show a scroll indicator at the top in dragging.
                    switch layoutAdapter.layout.interactiveEdge {
                    case .top where offset >= 0 && velocity.y <= 0:
                        unlockScrollView()
                        return
                    case .bottom where offset <= offsetMax && velocity.y >= 0:
                        unlockScrollView()
                        return
                    default:
                        break
                    }
                    if state == layoutAdapter.edgeMostState {
                        // Adjust a small gap of the scroll offset just after swiping down starts in the grabber area.
                        if grabberAreaFrame.contains(location), grabberAreaFrame.contains(initialLocation) {
                            scrollView.setContentOffset(initialScrollOffset, animated: false)
                        }
                    }
                } else {
                    if state == layoutAdapter.edgeMostState {
                        switch layoutAdapter.layout.interactiveEdge {
                        case .top where offset < 0 && velocity.y > 0:
                            // Hide a scroll indicator just before starting an interaction by swiping a panel down.
                            lockScrollView()
                        case .top where offset > 0 && velocity.y < 0:
                            // Show a scroll indicator when an animation is interrupted at the top and content is scrolled up
                            unlockScrollView()
                        case .bottom where offset > offsetMax && velocity.y < 0:
                            lockScrollView()
                        case .bottom where offset < offsetMax && velocity.y > 0:
                            unlockScrollView()
                        default:
                            break
                        }
                        // Adjust a small gap of the scroll offset just before swiping down starts in the grabber area,
                        if grabberAreaFrame.contains(location), grabberAreaFrame.contains(initialLocation) {
                            scrollView.setContentOffset(initialScrollOffset, animated: false)
                        }
                    }
                }
            }
        case panGestureRecognizer:
            let translation = panGesture.translation(in: panGestureRecognizer.view!.superview)
            let location = panGesture.location(in: panGesture.view)

            log.debug("panel gesture(\(state):\(panGesture.state)) --",
                "translation =  \(translation.y), location = \(location.y), velocity = \(velocity.y)")

            if interactionInProgress == false, isDecelerating == false,
                let vc = viewcontroller, vc.delegate?.floatingPanelShouldBeginDragging?(vc) == false {
                return
            }

            if let animator = self.animator {
                guard 0 >= layoutAdapter.offsetFromEdgeMostBuffer else { return }
                log.debug("panel animation(interruptible: \(animator.isInterruptible)) interrupted!!!")
                if animator.isInterruptible {
                    animator.stopAnimation(false)
                    // A user can stop a panel at the nearest Y of a target position so this fine-tunes
                    // the a small gap between the presentation layer frame and model layer frame
                    // to unlock scroll view properly at finishAnimation(at:)
                    if abs(layoutAdapter.offsetFromEdgeMost) <= 1.0 {
                        surfaceView.frame.origin.y = layoutAdapter.edgeMostY
                    }
                    animator.finishAnimation(at: .current)
                } else {
                    self.animator = nil
                }
            }

            if panGesture.state == .began {
                panningBegan(at: location)
                return
            }

            if shouldScrollViewHandleTouch(scrollView, point: location, velocity: velocity) {
                return
            }

            switch panGesture.state {
            case .changed:
                if interactionInProgress == false {
                    startInteraction(with: translation, at: location)
                }
                panningChange(with: translation)
            case .ended, .cancelled, .failed:
                if interactionInProgress == false {
                    startInteraction(with: translation, at: location)
                    // Workaround: Prevent stopping the surface view b/w anchors if the pan gesture
                    // doesn't pass through .changed state after an interruptible animator is interrupted.
                    let dy = translation.y - .leastNonzeroMagnitude
                    layoutAdapter.updateInteractiveEdgeConstraint(diff: dy,
                                                                  allowsTopBuffer: true,
                                                                  with: behaviorAdapter.behavior)
                }
                panningEnd(with: translation, velocity: velocity)
            default:
                break
            }
        default:
            return
        }
    }

    private func shouldScrollViewHandleTouch(_ scrollView: UIScrollView?, point: CGPoint, velocity: CGPoint) -> Bool {
        // When no scrollView, nothing to handle.
        guard let scrollView = scrollView else { return false }

        // For _UISwipeActionPanGestureRecognizer
        if let scrollGestureRecognizers = scrollView.gestureRecognizers {
            for gesture in scrollGestureRecognizers {
                guard gesture.state == .began || gesture.state == .changed
                else { continue }

                if gesture !=  scrollView.panGestureRecognizer {
                    return true
                }
            }
        }

        guard
            state == layoutAdapter.edgeMostState,  // When not top most(i.e. .full), don't scroll.
            interactionInProgress == false,        // When interaction already in progress, don't scroll.
            0 == layoutAdapter.offsetFromEdgeMost
        else {
            return false
        }

        // When the current and initial point within grabber area, do scroll.
        if grabberAreaFrame.contains(point), !grabberAreaFrame.contains(initialLocation) {
            return true
        }

        guard
            scrollView.frame.contains(initialLocation), // When initialLocation not in scrollView, don't scroll.
            !grabberAreaFrame.contains(point)           // When point within grabber area, don't scroll.
        else {
            return false
        }

        let offset = scrollView.contentOffset.y - scrollView.contentOffsetZero.y
        let offsetMax = max(scrollView.contentSize.height - scrollView.bounds.height, 0.0)
        // The zero offset must be excluded because the offset is usually zero
        // after a panel moves from half/tip to full.
        switch layoutAdapter.layout.interactiveEdge {
        case .top:
            if  offset > 0.0 {
                return true
            }
            if velocity.y <= 0 {
                return true
            }
        case .bottom:
            if  offset < offsetMax {
                return true
            }
            if velocity.y >= 0 {
                return true
            }
        }

        if scrollView.isDecelerating {
            return true
        }

        return false
    }

    private func panningBegan(at location: CGPoint) {
        // A user interaction does not always start from Began state of the pan gesture
        // because it can be recognized in scrolling a content in a content view controller.
        // So here just preserve the current state if needed.
        log.debug("panningBegan -- location = \(location.y)")
        initialLocation = location

        guard let scrollView = scrollView else { return }
        if state == layoutAdapter.edgeMostState {
            if grabberAreaFrame.contains(location) {
                initialScrollOffset = scrollView.contentOffset
            }
        } else {
            initialScrollOffset = scrollView.contentOffset
        }
    }

    private func panningChange(with translation: CGPoint) {
        log.debug("panningChange -- translation = \(translation.y)")
        let preY = surfaceEdgeY
        let dy = translation.y - initialTranslationY
        let nextY = edgeY(frame: initialFrame.offsetBy(dx: 0.0, dy: dy))

        layoutAdapter.updateInteractiveEdgeConstraint(diff: dy,
                                                      allowsTopBuffer: allowsTopBuffer(preY: preY, nextY: nextY, dy: dy),
                                                      with: behaviorAdapter.behavior)

        let currentY = surfaceEdgeY
        backdropView.alpha = getBackdropAlpha(at: currentY, with: translation)
        preserveContentVCLayoutIfNeeded()

        let didMove = (preY != currentY)
        guard didMove else { return }

        if let vc = viewcontroller {
            vc.delegate?.floatingPanelDidMove?(vc)
        }
    }

    private func allowsTopBuffer(preY: CGFloat, nextY: CGFloat, dy: CGFloat) -> Bool {
        if let scrollView = scrollView, scrollView.panGestureRecognizer.state == .changed,
            preY > 0 && preY > nextY {
            return false
        } else {
            return true
        }
    }

    private var disabledFixedEdgeAutoLayout = false
    private var disabledAutoLayoutItems: Set<NSLayoutConstraint> = []
    // Prevent stretching a view having a constraint to SafeArea.bottom in an overflow
    // from the full position because SafeArea is global in a screen.
    private func preserveContentVCLayoutIfNeeded() {
        guard let vc = viewcontroller else { return }
        guard vc.contentMode != .fitToBounds else { return }

        let fixedAnchor: NSLayoutYAxisAnchor? = {
            switch layoutAdapter.layout.interactiveEdge {
            case .top:
                return vc.contentViewController?.fp_safeAreaLayoutGuide.bottomAnchor
            case .bottom:
                return vc.contentViewController?.fp_safeAreaLayoutGuide.topAnchor
            }
        }()
        // Must include position Y of the most state
        if (0 <= layoutAdapter.offsetFromEdgeMost) {
            if !disabledFixedEdgeAutoLayout {
                disabledAutoLayoutItems.removeAll()
                vc.contentViewController?.view?.constraints.forEach({ (const) in
                    switch fixedAnchor {
                    case const.firstAnchor:
                        (const.secondItem as? UIView)?.disableAutoLayout()
                        const.isActive = false
                        disabledAutoLayoutItems.insert(const)
                    case const.secondAnchor:
                        (const.firstItem as? UIView)?.disableAutoLayout()
                        const.isActive = false
                        disabledAutoLayoutItems.insert(const)
                    default:
                        break
                    }
                })
            }
            disabledFixedEdgeAutoLayout = true
        } else {
            if disabledFixedEdgeAutoLayout {
                disabledAutoLayoutItems.forEach({ (const) in
                    switch fixedAnchor {
                    case const.firstAnchor:
                        (const.secondItem as? UIView)?.enableAutoLayout()
                        const.isActive = true
                    case const.secondAnchor:
                        (const.firstItem as? UIView)?.enableAutoLayout()
                        const.isActive = true
                    default:
                        break
                    }
                })
                disabledAutoLayoutItems.removeAll()
            }
            disabledFixedEdgeAutoLayout = false
        }
    }

    private func panningEnd(with translation: CGPoint, velocity: CGPoint) {
        log.debug("panningEnd -- translation = \(translation.y), velocity = \(velocity.y)")

        if state == .hidden {
            log.debug("Already hidden")
            return
        }

        stopScrollDeceleration = (0 > layoutAdapter.offsetFromEdgeMost) // Projecting the dragging to the scroll dragging or not
        if stopScrollDeceleration {
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.stopScrollingWithDeceleration(at: self.initialScrollOffset)
            }
        }

        let currentY = surfaceEdgeY
        let targetPosition = self.targetPosition(from: currentY, with: velocity)
        let distance = self.distance(to: targetPosition)

        endInteraction(for: targetPosition)

        if isRemovalInteractionEnabled, layoutAdapter.edgeLeastState == state {
            let velocityVector = (distance != 0) ? CGVector(dx: 0, dy: min(velocity.y/distance, behaviorAdapter.behavior.removalVelocity ?? FloatingPanelDefaultBehavior().removalVelocity)) : .zero
            // `velocityVector` will be replaced by just a velocity(not vector) when FloatingPanelRemovalInteraction will be added.
            if shouldStartRemovalAnimation(with: velocityVector), let vc = viewcontroller {
                vc.delegate?.floatingPanelDidEndDraggingToRemove?(vc, withVelocity: velocity)
                let animationVector = CGVector(dx: abs(velocityVector.dx), dy: abs(velocityVector.dy))
                startRemovalAnimation(vc, with: animationVector) { [weak self] in
                    self?.finishRemovalAnimation()
                }
                return
            }
        }

        if let vc = viewcontroller {
            vc.delegate?.floatingPanelDidEndDragging?(vc, withVelocity: velocity, targetState: targetPosition)
        }

        if scrollView != nil, !stopScrollDeceleration,
            0 == layoutAdapter.offsetFromEdgeMost,
            targetPosition == layoutAdapter.edgeMostState {
            self.state = targetPosition
            self.updateLayout(to: targetPosition)
            self.unlockScrollView()
            return
        }

        // Workaround: Disable a tracking scroll to prevent bouncing a scroll content in a panel animating
        let isScrollEnabled = scrollView?.isScrollEnabled
        if let scrollView = scrollView, targetPosition != .full {
            scrollView.isScrollEnabled = false
        }

        startAnimation(to: targetPosition, at: distance, with: velocity)

        // Workaround: Reset `self.scrollView.isScrollEnabled`
        if let scrollView = scrollView, targetPosition != .full,
            let isScrollEnabled = isScrollEnabled {
            scrollView.isScrollEnabled = isScrollEnabled
        }
    }

    private func shouldStartRemovalAnimation(with velocityVector: CGVector) -> Bool {
        let posY = layoutAdapter.positionY(for: state)
        let currentY = surfaceEdgeY
        let hiddenY = layoutAdapter.positionY(for: .hidden)
        let vth = behaviorAdapter.behavior.removalVelocity ?? FloatingPanelDefaultBehavior().removalProgress
        let pth = max(min(behaviorAdapter.behavior.removalProgress ?? FloatingPanelDefaultBehavior().removalVelocity, 1.0), 0.0)

        let num = (currentY - posY)
        let den = (hiddenY - posY)

        guard num >= 0, den != 0, (num / den >= pth || velocityVector.dy == abs(vth))
        else { return false }

        return true
    }

    private func startRemovalAnimation(_ vc: FloatingPanelController, with velocityVector: CGVector, completion: (() -> Void)?) {
        let animator = behaviorAdapter.behavior.removalInteractionAnimator?(vc, with: velocityVector) ?? FloatingPanelDefaultBehavior().removalInteractionAnimator(vc, with: velocityVector)

        animator.addAnimations { [weak self] in
            self?.state = .hidden
            self?.updateLayout(to: .hidden)
        }
        animator.addCompletion({ _ in
            self.animator = nil
            completion?()
        })
        self.animator = animator
        animator.startAnimation()
    }

    private func finishRemovalAnimation() {
        viewcontroller?.dismiss(animated: false) { [weak self] in
            guard let vc = self?.viewcontroller else { return }
            vc.delegate?.floatingPanelDidEndRemove?(vc)
        }
    }

    private func startInteraction(with translation: CGPoint, at location: CGPoint) {
        /* Don't lock a scroll view to show a scroll indicator after hitting the top */
        log.debug("startInteraction  -- translation = \(translation.y), location = \(location.y)")
        guard interactionInProgress == false else { return }

        var offset: CGPoint = .zero

        initialFrame = surfaceView.frame
        if state == layoutAdapter.topMostState, let scrollView = scrollView {
            if grabberAreaFrame.contains(location) {
                initialScrollOffset = scrollView.contentOffset
            } else {
                // Fit the surface bounds to a scroll offset content by startInteraction(at:offset:)
                offset = CGPoint(x: -scrollView.contentOffset.x, y: -scrollView.contentOffset.y)
                initialScrollOffset = scrollView.contentOffsetZero
            }
            log.debug("initial scroll offset --", initialScrollOffset)
        }

        initialTranslationY = translation.y

        if let vc = viewcontroller {
            vc.delegate?.floatingPanelWillBeginDragging?(vc)
        }

        layoutAdapter.startInteraction(at: state, offset: offset)

        interactionInProgress = true

        lockScrollView()
    }

    private func endInteraction(for targetPosition: FloatingPanelState) {
        log.debug("endInteraction to \(targetPosition)")

        if let scrollView = scrollView {
            log.debug("endInteraction -- scroll offset = \(scrollView.contentOffset)")
        }

        interactionInProgress = false

        // Prevent to keep a scroll view indicator visible at the half/tip position
        if targetPosition != layoutAdapter.topMostState {
            lockScrollView()
        }

        layoutAdapter.endInteraction(at: targetPosition)
    }

    private func tearDownActiveInteraction() {
        // Cancel the pan gesture so that panningEnd(with:velocity:) is called
        panGestureRecognizer.isEnabled = false
        panGestureRecognizer.isEnabled = true
    }

    private func startAnimation(to targetPosition: FloatingPanelState, at distance: CGFloat, with velocity: CGPoint) {
        log.debug("startAnimation to \(targetPosition) -- distance = \(distance), velocity = \(velocity.y)")
        guard let vc = viewcontroller else { return }

        isDecelerating = true

        vc.delegate?.floatingPanelWillBeginDecelerating?(vc)

        let velocityVector = (distance != 0) ? CGVector(dx: 0, dy: abs(velocity.y)/distance) : .zero
        let animator = behaviorAdapter.behavior.interactionAnimator?(vc, to: targetPosition, with: velocityVector) ?? FloatingPanelDefaultBehavior().interactionAnimator(vc, to: targetPosition, with: velocityVector)
        animator.addAnimations { [weak self] in
            guard let `self` = self, let vc = self.viewcontroller else { return }
            self.state = targetPosition
            if animator.isInterruptible {
                switch vc.contentMode {
                case .fitToBounds:
                    UIView.performWithLinear(startTime: 0.0, relativeDuration: 0.75) {
                        self.layoutAdapter.activateFixedLayout()
                        self.surfaceView.superview!.layoutIfNeeded()
                    }
                case .static:
                    self.layoutAdapter.activateFixedLayout()
                }
            } else {
                self.layoutAdapter.activateFixedLayout()
            }
            self.layoutAdapter.activateInteractiveLayout(of: targetPosition)
        }
        animator.addCompletion { [weak self] pos in
            // Prevent calling `finishAnimation(at:)` by the old animator whose `isInterruptive` is false
            // when a new animator has been started after the old one is interrupted.
            guard let `self` = self, self.animator == animator else { return }
            self.finishAnimation(at: targetPosition)
        }
        self.animator = animator
        animator.startAnimation()
    }

    private func finishAnimation(at targetPosition: FloatingPanelState) {
        log.debug("finishAnimation to \(targetPosition)")

        self.isDecelerating = false
        self.animator = nil

        if let vc = viewcontroller {
            vc.delegate?.floatingPanelDidEndDecelerating?(vc)
        }

        if let scrollView = scrollView {
            log.debug("finishAnimation -- scroll offset = \(scrollView.contentOffset)")
        }

        stopScrollDeceleration = false

        log.debug("finishAnimation -- state = \(state) surface.edgeY = \(surfaceEdgeY) edgeMostY = \(layoutAdapter.edgeMostY)")
        if state == layoutAdapter.edgeMostState, abs(layoutAdapter.offsetFromEdgeMost) <= 1.0 {
            unlockScrollView()
        }
    }

    private func distance(to targetPosition: FloatingPanelState) -> CGFloat {
        let currentY = surfaceEdgeY
        let targetY = layoutAdapter.positionY(for: targetPosition)
        return CGFloat(abs(currentY - targetY))
    }

    // Distance travelled after decelerating to zero velocity at a constant rate.
    // Refer to the slides p176 of [Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/)
    private func project(initialVelocity: CGFloat, decelerationRate: CGFloat) -> CGFloat {
        return (initialVelocity / 1000.0) * decelerationRate / (1.0 - decelerationRate)
    }

    func targetPosition(from currentY: CGFloat, with velocity: CGPoint) -> (FloatingPanelState) {
        guard let vc = viewcontroller else { return state }
        let sortedPositions = layoutAdapter.sortedDirectionalPositions

        guard sortedPositions.count > 1 else {
            return state
        }

        // Projection
        let decelerationRate = behaviorAdapter.behavior.momentumProjectionRate?(vc) ?? FloatingPanelDefaultBehavior().momentumProjectionRate(vc)
        let baseY = abs(layoutAdapter.positionY(for: layoutAdapter.bottomMostState) - layoutAdapter.positionY(for: layoutAdapter.topMostState))
        let vecY = velocity.y / baseY
        var pY = project(initialVelocity: vecY, decelerationRate: decelerationRate) * baseY + currentY

        let forwardY = velocity.y == 0 ? (currentY - layoutAdapter.positionY(for: state) > 0) : velocity.y > 0

        let segment = layoutAdapter.segument(at: pY, forward: forwardY)

        var fromPos: FloatingPanelState
        var toPos: FloatingPanelState

        let (lowerPos, upperPos) = (segment.lower ?? sortedPositions.first!, segment.upper ?? sortedPositions.last!)
        (fromPos, toPos) = forwardY ? (lowerPos, upperPos) : (upperPos, lowerPos)

        if behaviorAdapter.behavior.shouldProjectMomentum?(vc, for: toPos) ?? FloatingPanelDefaultBehavior().shouldProjectMomentum(vc, for: toPos) == false {
            let segment = layoutAdapter.segument(at: currentY, forward: forwardY)
            var (lowerPos, upperPos) = (segment.lower ?? sortedPositions.first!, segment.upper ?? sortedPositions.last!)
            // Equate the segment out of {top,bottom} most state to the {top,bottom} most segment
            if lowerPos == upperPos {
                if forwardY {
                    upperPos = lowerPos.next(in: sortedPositions)
                } else {
                    lowerPos = lowerPos.pre(in: sortedPositions)
                }
            }
            (fromPos, toPos) = forwardY ? (lowerPos, upperPos) : (upperPos, lowerPos)
            // Block a projection to a segment over the next from the current segment
            // (= Trim pY with the current segment)
            if forwardY {
                pY = max(min(pY, layoutAdapter.positionY(for: toPos.next(in: sortedPositions))), layoutAdapter.positionY(for: fromPos))
            } else {
                pY = max(min(pY, layoutAdapter.positionY(for: fromPos)), layoutAdapter.positionY(for: toPos.pre(in: sortedPositions)))
            }
        }

        // Redirection
        let redirectionalProgress = max(min(behaviorAdapter.behavior.redirectionalProgress?(vc, from: fromPos, to: toPos) ?? FloatingPanelDefaultBehavior().redirectionalProgress(vc,from: fromPos, to: toPos), 1.0), 0.0)
        let progress = abs(pY - layoutAdapter.positionY(for: fromPos)) / abs(layoutAdapter.positionY(for: fromPos) - layoutAdapter.positionY(for: toPos))
        return progress > redirectionalProgress ? toPos : fromPos
    }

    // MARK: - ScrollView handling

    private func lockScrollView() {
        guard let scrollView = scrollView else { return }

        if scrollView.isLocked {
            log.debug("Already scroll locked.")
            return
        }
        log.debug("lock scroll view")

        scrollBouncable = scrollView.bounces
        scrollIndictorVisible = scrollView.showsVerticalScrollIndicator

        scrollView.isDirectionalLockEnabled = true
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
    }

    private func unlockScrollView() {
        guard let scrollView = scrollView, scrollView.isLocked else { return }
        log.debug("unlock scroll view")

        scrollView.isDirectionalLockEnabled = false
        scrollView.bounces = scrollBouncable
        scrollView.showsVerticalScrollIndicator = scrollIndictorVisible
    }

    private func stopScrollingWithDeceleration(at contentOffset: CGPoint) {
        // Must use setContentOffset(_:animated) to force-stop deceleration
        scrollView?.setContentOffset(contentOffset, animated: false)
    }
}

class FloatingPanelPanGestureRecognizer: UIPanGestureRecognizer {
    fileprivate weak var floatingPanel: FloatingPanel?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        if floatingPanel?.animator != nil {
            self.state = .began
        }
    }
    override weak var delegate: UIGestureRecognizerDelegate? {
        get {
            return super.delegate
        }
        set {
            guard newValue is FloatingPanel else {
                let exception = NSException(name: .invalidArgumentException,
                                            reason: "FloatingPanelController's built-in pan gesture recognizer must have its controller as its delegate.",
                                            userInfo: nil)
                exception.raise()
                return
            }
            super.delegate = newValue
        }
    }
}
