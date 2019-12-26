//
//  Created by Shin Yamamoto on 2018/09/18.
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import UIKit
import simd

internal func displayTrunc(_ v: CGFloat, by s: CGFloat) -> CGFloat {
    let base = (1 / s)
    let t = v.rounded(.down)
    return t + ((v - t) / base).rounded(.toNearestOrAwayFromZero) * base
}

internal func displayEqual(_ lhs: CGFloat, _ rhs: CGFloat, by displayScale: CGFloat) -> Bool {
    return displayTrunc(lhs, by: displayScale) == displayTrunc(rhs, by: displayScale)
}

protocol LayoutGuideProvider {
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var heightAnchor: NSLayoutDimension { get }
}
extension UILayoutGuide: LayoutGuideProvider {}

private class CustomLayoutGuide: LayoutGuideProvider {
    let topAnchor: NSLayoutYAxisAnchor
    let bottomAnchor: NSLayoutYAxisAnchor
    let heightAnchor: NSLayoutDimension
    init(topAnchor: NSLayoutYAxisAnchor,
         bottomAnchor: NSLayoutYAxisAnchor,
         heightAnchor: NSLayoutDimension) {
        self.topAnchor = topAnchor
        self.bottomAnchor = bottomAnchor
        self.heightAnchor = heightAnchor
    }
}

extension UIViewController {
    @objc var fp_safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return view.safeAreaInsets
        } else {
            return UIEdgeInsets(top: topLayoutGuide.length,
                                left: 0.0,
                                bottom: bottomLayoutGuide.length,
                                right: 0.0)
        }
    }

    var fp_safeAreaLayoutGuide: LayoutGuideProvider {
        if #available(iOS 11.0, *) {
            return view!.safeAreaLayoutGuide
        } else {
            return CustomLayoutGuide(topAnchor: topLayoutGuide.bottomAnchor,
                                     bottomAnchor: bottomLayoutGuide.topAnchor,
                                     heightAnchor: topLayoutGuide.bottomAnchor.anchorWithOffset(to: bottomLayoutGuide.topAnchor))
        }
    }
}

protocol SideLayoutGuideProvider {
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
}

extension UIView: SideLayoutGuideProvider {}
extension UILayoutGuide: SideLayoutGuideProvider {}

// The reason why UIView has no extensions of safe area insets and top/bottom guides
// is for iOS10 compat.
extension UIView {
    var sideLayoutGuide: SideLayoutGuideProvider {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide
        } else {
            return self
        }
    }

    var presentationFrame: CGRect {
        return layer.presentation()?.frame ?? frame
    }
}

extension UIView {
    func disableAutoLayout() {
        let frame = self.frame
        translatesAutoresizingMaskIntoConstraints = true
        self.frame = frame
    }
    func enableAutoLayout() {
        translatesAutoresizingMaskIntoConstraints = false
    }

    static func performWithLinear(startTime: Double = 0.0, relativeDuration: Double = 1.0, _ animations: @escaping (() -> Void)) {
        UIView.animateKeyframes(withDuration: 0.0, delay: 0.0, options: [.calculationModeCubic], animations: {
            UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: relativeDuration, animations: animations)
        }, completion: nil)
    }
}

#if __FP_LOG
extension UIGestureRecognizer.State: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .began: return "began"
        case .changed: return "changed"
        case .failed: return "failed"
        case .cancelled: return "cancelled"
        case .ended: return "endeded"
        case .possible: return "possible"
        @unknown default: return ""
        }
    }
}
#endif

extension UIScrollView {
    var contentOffsetZero: CGPoint {
        return CGPoint(x: 0.0, y: 0.0 - contentInset.top)
    }
    var isLocked: Bool {
        return !showsVerticalScrollIndicator && !bounces &&  isDirectionalLockEnabled
    }
}

extension UISpringTimingParameters {
    public convenience init(dampingRatio: CGFloat, frequencyResponse: CGFloat, initialVelocity: CGVector = .zero) {
        let mass = 1 as CGFloat
        let stiffness = pow(2 * .pi / frequencyResponse, 2) * mass
        let damp = 4 * .pi * dampingRatio * mass / frequencyResponse
        self.init(mass: mass, stiffness: stiffness, damping: damp, initialVelocity: initialVelocity)
    }
}

extension CGPoint {
    static var nan: CGPoint {
        return CGPoint(x: CGFloat.nan,
                       y: CGFloat.nan)
    }
}

extension UITraitCollection {
    func shouldUpdateLayout(from previous: UITraitCollection) -> Bool {
        return previous.horizontalSizeClass != horizontalSizeClass
            || previous.verticalSizeClass != verticalSizeClass
            || previous.preferredContentSizeCategory != preferredContentSizeCategory
            || previous.layoutDirection != layoutDirection
    }
}

extension NSLayoutConstraint {
    static func activate(constraint: NSLayoutConstraint?) {
        guard let constraint = constraint else { return }
        self.activate([constraint])
    }
    static func deactivate(constraint: NSLayoutConstraint?) {
        guard let constraint = constraint else { return }
        self.deactivate([constraint])
    }
}

extension UIEdgeInsets {
    var horizontalInset: CGFloat {
        return self.left + self.right
    }
    var verticalInset: CGFloat {
        return self.top + self.bottom
    }
}
