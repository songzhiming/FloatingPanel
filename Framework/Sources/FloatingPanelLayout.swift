//
//  Created by Shin Yamamoto on 2018/09/27.
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import UIKit

@objc public enum FloatingPanelLayoutReferenceGuide: Int {
    case superview = 0
    case safeArea = 1
}

@objc public enum FloatingPanelRectEdge: Int {
    case top
    case bottom
}

@objc public protocol FloatingPanelLayoutAnchoring {
    var referenceGuide: FloatingPanelLayoutReferenceGuide { get }
    var referenceEdge: UIRectEdge { get }
    var isAbsolute: Bool { get }
    var value: CGFloat { get }
    func layoutConstraints(_ vc: FloatingPanelController, for position: FloatingPanelRectEdge) -> [NSLayoutConstraint]
}

@objc final public class FloatingPanelLayoutAnchor: NSObject, FloatingPanelLayoutAnchoring /*, NSCopying */ {
    public static let hidden: FloatingPanelLayoutAnchor = FloatingPanelLayoutAnchor(absoluteInset: 0.0, referenceGuide: .superview, edge: [])
    @objc public init(absoluteInset: CGFloat, referenceGuide: FloatingPanelLayoutReferenceGuide, edge: UIRectEdge) {
        self.inset = absoluteInset
        self.referenceGuide = referenceGuide
        self.referenceEdge = edge
        self.isAbsolute = true
    }
    @objc public init(fractionalInset: CGFloat, referenceGuide: FloatingPanelLayoutReferenceGuide, edge: UIRectEdge) {
        self.inset = fractionalInset
        self.referenceGuide = referenceGuide
        self.referenceEdge = edge
        self.isAbsolute = false
    }
    let inset: CGFloat
    @objc public var value: CGFloat {
        return inset
    }
    @objc public let referenceGuide: FloatingPanelLayoutReferenceGuide
    @objc public let referenceEdge: UIRectEdge
    @objc public let isAbsolute: Bool
}

public extension FloatingPanelLayoutAnchor {
    func layoutConstraints(_ vc: FloatingPanelController, for position: FloatingPanelRectEdge) -> [NSLayoutConstraint] {
        let edgeAnchor: NSLayoutYAxisAnchor = {
            switch position {
            case .top: return vc.surfaceView.bottomAnchor
            case .bottom: return vc.surfaceView.topAnchor
            }
        }()
        if self == FloatingPanelLayoutAnchor.hidden {
            switch position {
            case .top:
                return [edgeAnchor.constraint(equalTo: vc.view.topAnchor, constant: 0.0)]
            case .bottom:
                return [edgeAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: 0.0)]
            }
        }
        switch self.referenceGuide {
        case .superview:
            switch referenceEdge {
            case .top:
                if isAbsolute == false {
                    let offsetAnchor = vc.view.topAnchor.anchorWithOffset(to: edgeAnchor)
                    return [offsetAnchor.constraint(equalTo: vc.view.heightAnchor, multiplier: value)]
                }
                return [edgeAnchor.constraint(equalTo:  vc.view.topAnchor, constant: value)]
            case .bottom:
                if isAbsolute == false {
                    let offsetAnchor = edgeAnchor.anchorWithOffset(to: vc.view.bottomAnchor)
                    return [offsetAnchor.constraint(equalTo: vc.view.heightAnchor, multiplier: value)]
                }
                return [edgeAnchor.constraint(equalTo:  vc.view.bottomAnchor, constant: -value)]
            default:
                fatalError("Unsupported edges")
            }
        case .safeArea:
            switch referenceEdge {
            case .top:
                if isAbsolute == false {
                    let offsetAnchor = vc.fp_safeAreaLayoutGuide.topAnchor.anchorWithOffset(to: edgeAnchor)
                    return [offsetAnchor.constraint(equalTo: vc.fp_safeAreaLayoutGuide.heightAnchor, multiplier: value)]
                }
                return [edgeAnchor.constraint(equalTo:  vc.fp_safeAreaLayoutGuide.topAnchor, constant: value)]
            case .bottom:
                if isAbsolute == false {
                    let offsetAnchor = edgeAnchor.anchorWithOffset(to: vc.fp_safeAreaLayoutGuide.bottomAnchor)
                    return [offsetAnchor.constraint(equalTo: vc.fp_safeAreaLayoutGuide.heightAnchor, multiplier: value)]
                }
                return [edgeAnchor.constraint(equalTo:  vc.fp_safeAreaLayoutGuide.bottomAnchor, constant: -value)]
            default:
                fatalError("Unsupported edges")
            }
        }
    }
}

@objc final public class FloatingPanelIntrinsicLayoutAnchor: NSObject, FloatingPanelLayoutAnchoring /*, NSCopying */ {
    @objc public init(absoluteVisibleOffset offset: CGFloat, referenceGuide: FloatingPanelLayoutReferenceGuide) {
        self.offset = offset
        self.referenceGuide = referenceGuide
        self.referenceEdge = []
        self.isAbsolute = true
    }
    // offset = 0.0: All content visible
    // offset = 1.0: All content invisible
    @objc public init(fractionalVisibleOffset offset: CGFloat, referenceGuide: FloatingPanelLayoutReferenceGuide) {
        self.offset = offset
        self.referenceGuide = referenceGuide
        self.referenceEdge = []
        self.isAbsolute = false
    }
    let offset: CGFloat
    @objc public var value: CGFloat {
        return offset
    }
    @objc public let referenceGuide: FloatingPanelLayoutReferenceGuide
    @objc public let referenceEdge: UIRectEdge
    @objc public let isAbsolute: Bool
}

public extension FloatingPanelIntrinsicLayoutAnchor {
    func layoutConstraints(_ vc: FloatingPanelController, for position: FloatingPanelRectEdge) -> [NSLayoutConstraint] {
        let surfaceIntrinsicHeight = vc.surfaceView.intrinsicContentSize.height
        switch self.referenceGuide {
        case .superview:
            let offsetAnchor: NSLayoutDimension = {
                switch position {
                case .top:
                    return vc.view.topAnchor.anchorWithOffset(to: vc.surfaceView.bottomAnchor)
                case .bottom:
                    return vc.surfaceView.topAnchor.anchorWithOffset(to: vc.view.bottomAnchor)
                }
            }()
            let constraint: NSLayoutConstraint = {
                if isAbsolute {
                    return offsetAnchor.constraint(equalToConstant: surfaceIntrinsicHeight - offset)
                }
                return offsetAnchor.constraint(equalToConstant: surfaceIntrinsicHeight * (1 - offset))
            }()
            return [constraint]
        case .safeArea:
            let offsetAnchor: NSLayoutDimension = {
                switch position {
                case .top:
                    return vc.fp_safeAreaLayoutGuide.topAnchor.anchorWithOffset(to: vc.surfaceView.bottomAnchor)
                case .bottom:
                    return vc.surfaceView.topAnchor.anchorWithOffset(to: vc.fp_safeAreaLayoutGuide.bottomAnchor)
                }
            }()
            let constraint: NSLayoutConstraint = {
                if isAbsolute {
                    return offsetAnchor.constraint(equalToConstant: surfaceIntrinsicHeight - offset)
                }
                return offsetAnchor.constraint(equalToConstant: surfaceIntrinsicHeight * (1 - offset))
            }()
            return [constraint]
        }
    }
}

@objc public protocol FloatingPanelLayout {
    /// TODO: Write doc comment
    @objc var position: FloatingPanelRectEdge { get }

    /// TODO: Write doc comment
    @objc var initialState: FloatingPanelState { get }

    /// TODO: Write doc comment
    @objc var layoutAnchors: [FloatingPanelState: FloatingPanelLayoutAnchoring] { get }

    /// Return the interaction buffer from the top/bottom-most position. Default is 6.0.
    ///
    /// - Important:
    /// The specified bottom buffer is ignored when `FloatingPanelController.isRemovalInteractionEnabled` is set to true.
    @objc optional func interactionBuffer(for edge: FloatingPanelRectEdge) -> CGFloat

    /// Returns X-axis and width layout constraints of the surface view of a floating panel.
    /// You must not include any Y-axis and height layout constraints of the surface view
    /// because their constraints will be configured by the floating panel controller.
    /// By default, the width of a surface view fits a safe area.
    @objc optional func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint]

    /// Returns a CGFloat value to determine the backdrop view's alpha for a position.
    ///
    /// Default is 0.3 at full position, otherwise 0.0.
    @objc optional func backdropAlpha(for state: FloatingPanelState) -> CGFloat
}

extension FloatingPanelLayout {
    var interactiveEdge: FloatingPanelRectEdge {
        switch self.position {
        case .top:
            return .bottom
        case .bottom:
            return .top
        }
    }
}

@objcMembers
open class FloatingPanelDefaultLayout: NSObject, FloatingPanelLayout {
    public override init() {
        super.init()
    }
    open var initialState: FloatingPanelState {
        return .half
    }

    open var layoutAnchors: [FloatingPanelState: FloatingPanelLayoutAnchoring]  {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteInset: 18.0, referenceGuide: .safeArea, edge: .top),
            .half: FloatingPanelLayoutAnchor(absoluteInset: 262.0, referenceGuide: .safeArea, edge: .bottom),
            .tip: FloatingPanelLayoutAnchor(absoluteInset: 69.0, referenceGuide: .safeArea, edge: .bottom),
            //.hidden: FloatingPanelLayoutAnchor.hidden
        ]
    }

    open func interactionBuffer(for edge: FloatingPanelRectEdge) -> CGFloat {
        return 6.0
    }

    open var position: FloatingPanelRectEdge {
        return .bottom
    }

    open func prepareLayout(surfaceView: UIView, in view: UIView) -> [NSLayoutConstraint] {
        return [
            surfaceView.leftAnchor.constraint(equalTo: view.sideLayoutGuide.leftAnchor, constant: 0.0),
            surfaceView.rightAnchor.constraint(equalTo: view.sideLayoutGuide.rightAnchor, constant: 0.0),
        ]
    }

    open func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return state == .full ? 0.3 : 0.0
    }
}

struct LayoutSegment {
    let lower: FloatingPanelState?
    let upper: FloatingPanelState?
}

class FloatingPanelLayoutAdapter {
    weak var vc: FloatingPanelController!
    private weak var surfaceView: FloatingPanelSurfaceView!
    private weak var backdropView: FloatingPanelBackdropView!
    private let defaultLayout = FloatingPanelDefaultLayout()

    var layout: FloatingPanelLayout {
        didSet {
            surfaceView.interactiveEdge = layout.interactiveEdge
        }
    }

    private var safeAreaInsets: UIEdgeInsets {
        return vc?.fp_safeAreaInsets ?? .zero
    }

    private var initialConst: CGFloat = 0.0

    private var fixedConstraints: [NSLayoutConstraint] = []
    private var fullConstraints: [NSLayoutConstraint] = []
    private var halfConstraints: [NSLayoutConstraint] = []
    private var tipConstraints: [NSLayoutConstraint] = []
    private var offConstraints: [NSLayoutConstraint] = []
    private var fitToBoundsConstraint: NSLayoutConstraint?

    private(set) var interactiveEdgeConstraint: NSLayoutConstraint?

    private var heightConstraint: NSLayoutConstraint?

    var topInteractionBuffer: CGFloat {
        return layout.interactionBuffer?(for: .top) ?? defaultLayout.interactionBuffer(for: .top)
    }

    var bottomInteractionBuffer: CGFloat {
        return layout.interactionBuffer?(for: .bottom) ?? defaultLayout.interactionBuffer(for: .bottom)
    }

    var supportedPositions: Set<FloatingPanelState> {
        return Set(layout.layoutAnchors.keys)
    }

    var sortedDirectionalPositions: [FloatingPanelState] {
        return supportedPositions.sorted(by: {
            layout.interactiveEdge == .top ? $0.order < $1.order : $0.order > $1.order
        })
    }

    var topMostState: FloatingPanelState {
        switch layout.interactiveEdge {
        case .top:
            return supportedPositions.sorted(by: { $0.order < $1.order }).first ?? .hidden
        case .bottom:
            return supportedPositions.sorted(by: { $0.order < $1.order }).last ?? .hidden
        }
    }

    var bottomMostState: FloatingPanelState {
        switch layout.interactiveEdge {
        case .top:
            return supportedPositions.sorted(by: { $0.order < $1.order }).last ?? .hidden
        case .bottom:
            return supportedPositions.sorted(by: { $0.order < $1.order }).first ?? .hidden
        }
    }

    var edgeMostState: FloatingPanelState {
        switch layout.interactiveEdge {
        case .top: return topMostState
        case .bottom: return bottomMostState
        }
    }

    var edgeLeastState: FloatingPanelState {
        switch layout.interactiveEdge {
        case .top: return bottomMostState
        case .bottom: return topMostState
        }
    }

    var topY: CGFloat {
        return positionY(for: topMostState)
    }

    var bottomY: CGFloat {
        return positionY(for: bottomMostState)
    }

    var topMaxY: CGFloat {
        return topY - (layout.interactionBuffer?(for: .top) ?? defaultLayout.interactionBuffer(for: .top))
    }

    var bottomMaxY: CGFloat {
        return bottomY + (layout.interactionBuffer?(for: .bottom) ?? defaultLayout.interactionBuffer(for: .bottom))
    }

    var edgeMostY: CGFloat {
        switch layout.interactiveEdge {
        case .top: return topY
        case .bottom: return bottomY
        }
    }

    var adjustedContentInsets: UIEdgeInsets {
        switch layout.interactiveEdge {
        case .top:
            return UIEdgeInsets(top: 0.0,
                                left: 0.0,
                                bottom: safeAreaInsets.bottom,
                                right: 0.0)
        case .bottom:
            return UIEdgeInsets(top: safeAreaInsets.top,
                                left: 0.0,
                                bottom: 0.0,
                                right: 0.0)
        }
    }

    func positionY(for pos: FloatingPanelState) -> CGFloat {
        let bounds = vc.view.bounds
        let safeAreaBounds = vc.view.bounds.inset(by: vc.fp_safeAreaInsets)

        if pos == .hidden {
            switch layout.position {
            case .top: return 0.0
            case .bottom: return bounds.height
            }
        }

        guard let anchor = layout.layoutAnchors[pos] else {
            return .nan
        }

        switch anchor {
        case let ianchor as FloatingPanelIntrinsicLayoutAnchor:
            let surfaceIntrinsicHeight = surfaceView.intrinsicContentSize.height
            switch layout.position {
            case .top:
                var ret = surfaceIntrinsicHeight
                if ianchor.referenceGuide == .safeArea {
                    ret += safeAreaInsets.top
                }
                if ianchor.isAbsolute {
                    return ret - ianchor.offset
                } else {
                    return ret - surfaceIntrinsicHeight * ianchor.offset
                }
            case .bottom:
                var ret = bounds.height - surfaceIntrinsicHeight
                if ianchor.referenceGuide == .safeArea {
                    ret -= safeAreaInsets.bottom
                }
                if ianchor.isAbsolute {
                    return ret + ianchor.offset
                } else {
                    return ret + surfaceIntrinsicHeight * ianchor.offset
                }
            }
        default:
            switch anchor.referenceGuide {
            case .safeArea:
                switch anchor.referenceEdge {
                case .top:
                    let base = safeAreaBounds.minY
                    if anchor.isAbsolute {
                        return base + anchor.value
                    }
                    return base + safeAreaBounds.height * anchor.value
                case .bottom:
                    let base = safeAreaBounds.maxY
                    if anchor.isAbsolute {
                        return base - anchor.value
                    }
                    return base - (safeAreaBounds.height * anchor.value)
                default:
                    fatalError("Unsupported edges")
                }
            case .superview:
                switch anchor.referenceEdge {
                case .top:
                    let base = bounds.minY
                    if anchor.isAbsolute {
                        return base + anchor.value
                    }
                    return base + bounds.height * anchor.value
                case .bottom:
                    let base = bounds.maxY
                    if anchor.isAbsolute {
                        return base - anchor.value
                    }
                    return base - (bounds.height * anchor.value)
                default:
                    fatalError("Unsupported edges")
                }
            }
        }
    }

    init(vc: FloatingPanelController,
         surfaceView: FloatingPanelSurfaceView,
         backdropView: FloatingPanelBackdropView,
         layout: FloatingPanelLayout) {
        self.vc = vc
        self.layout = layout
        self.surfaceView = surfaceView
        self.backdropView = backdropView
    }

    var offsetFromEdgeMost: CGFloat {
        switch layout.interactiveEdge {
        case .top:
            return topY - surfaceView.presentationFrame.minY
        case .bottom:
            return surfaceView.presentationFrame.maxY - bottomY
        }
    }

    var offsetFromEdgeMostBuffer: CGFloat {
        switch layout.interactiveEdge {
        case .top:
            return topMaxY - surfaceView.presentationFrame.minY
        case .bottom:
            return surfaceView.presentationFrame.maxY - bottomMaxY
        }
    }

    func edgeY(_ frame: CGRect) -> CGFloat {
        switch layout.interactiveEdge {
        case .top:
            return frame.minY
        case .bottom:
            return frame.maxY
        }
    }

    func prepareLayout() {
        NSLayoutConstraint.deactivate(fixedConstraints + fullConstraints + halfConstraints + tipConstraints + offConstraints)
        NSLayoutConstraint.deactivate(constraint: self.heightConstraint)
        self.heightConstraint = nil
        NSLayoutConstraint.deactivate(constraint: self.fitToBoundsConstraint)
        self.fitToBoundsConstraint = nil

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        backdropView.translatesAutoresizingMaskIntoConstraints = false

        // Fixed constraints of surface and backdrop views
        let surfaceConstraints = layout.prepareLayout?(surfaceView: surfaceView, in: vc.view!) ?? defaultLayout.prepareLayout(surfaceView: surfaceView, in: vc.view!)
        let backdropConstraints = [
            backdropView.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 0.0),
            backdropView.leftAnchor.constraint(equalTo: vc.view.leftAnchor,constant: 0.0),
            backdropView.rightAnchor.constraint(equalTo: vc.view.rightAnchor, constant: 0.0),
            backdropView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: 0.0),
            ]

        fixedConstraints = surfaceConstraints + backdropConstraints

        if vc.contentMode == .fitToBounds {
            fitToBoundsConstraint = {
                switch layout.position {
                case .top:
                    return surfaceView.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 0.0)
                case .bottom:
                    return surfaceView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: 0.0)
                }
            }()
        }

        if let fullAnchor = layout.layoutAnchors[.full] {
            fullConstraints = fullAnchor.layoutConstraints(vc, for: layout.position)
        }
        if let halfAnchor = layout.layoutAnchors[.half] {
            halfConstraints = halfAnchor.layoutConstraints(vc, for: layout.position)
        }
        if let tipAnchors = layout.layoutAnchors[.tip] {
            tipConstraints = tipAnchors.layoutConstraints(vc, for: layout.position)
        }
        let hiddenAnchor = layout.layoutAnchors[.hidden] ?? (FloatingPanelLayoutAnchor.hidden as FloatingPanelLayoutAnchoring)
        offConstraints = hiddenAnchor.layoutConstraints(vc, for: layout.position)
    }

    func startInteraction(at state: FloatingPanelState, offset: CGPoint = .zero) {
        guard self.interactiveEdgeConstraint == nil else { return }
        NSLayoutConstraint.deactivate(fullConstraints + halfConstraints + tipConstraints + offConstraints)

        let edgeConst: NSLayoutConstraint
        switch layout.interactiveEdge {
        case .top:
            initialConst = surfaceView.frame.minY + offset.y
            edgeConst = surfaceView.topAnchor.constraint(equalTo: vc.view.topAnchor,
                                                         constant: initialConst)
        case .bottom:
            initialConst = surfaceView.frame.maxY + offset.y
            edgeConst = surfaceView.bottomAnchor.constraint(equalTo: vc.view.topAnchor,
                                                            constant: initialConst)
        }

        NSLayoutConstraint.activate([edgeConst])
        self.interactiveEdgeConstraint = edgeConst
    }

    func endInteraction(at state: FloatingPanelState) {
        // Don't deactivate `interactiveTopConstraint` here because it leads to
        // unsatisfiable constraints

        if self.interactiveEdgeConstraint == nil {
            // Actiavate `interactiveTopConstraint` for `fitToBounds` mode.
            // It goes throught this path when the pan gesture state jumps
            // from .begin to .end.
            startInteraction(at: state)
        }
    }

    // The method is separated from prepareLayout(to:) for the rotation support
    // It must be called in FloatingPanelController.traitCollectionDidChange(_:)
    func updateHeight() {
        guard let vc = vc else { return }
        NSLayoutConstraint.deactivate(constraint: heightConstraint)
        heightConstraint = nil

        if vc.contentMode == .fitToBounds {
            return
        }

        let anchor = layout.layoutAnchors[self.topMostState]!
        if anchor is FloatingPanelIntrinsicLayoutAnchor {
            let heightMargin: CGFloat
            switch layout.position {
            case .bottom:
                heightMargin = safeAreaInsets.bottom
            case .top:
                heightMargin = safeAreaInsets.top
            }
            let constant: CGFloat
            switch anchor.referenceGuide {
            case .safeArea:
                constant = surfaceView.intrinsicContentSize.height + heightMargin
            case .superview:
                constant = surfaceView.intrinsicContentSize.height
            }
            heightConstraint = surfaceView.heightAnchor.constraint(equalToConstant: constant)
        } else {
            switch layout.position {
            case .top:
                heightConstraint = surfaceView.heightAnchor.constraint(equalToConstant: positionY(for: self.bottomMostState))
            case .bottom:
                heightConstraint = vc.view.heightAnchor.constraint(equalTo: surfaceView.heightAnchor, constant: positionY(for: self.topMostState))
            }
        }
        NSLayoutConstraint.activate(constraint: heightConstraint)

        surfaceView.bottomOverflow = vc.view.bounds.height
    }

    // TODO: Support interactive bottom edge
    func updateInteractiveEdgeConstraint(diff: CGFloat, allowsTopBuffer: Bool, with behavior: FloatingPanelBehavior) {
        defer {
            layoutSurfaceIfNeeded() // MUST be called to update `surfaceView.frame`
            log.debug("update edge -- surface edge Y = \(self.edgeY(self.surfaceView.presentationFrame))")
        }

        let topMostConst: CGFloat = max(topY, 0.0) // The top boundary is equal to the related topAnchor.
        let bottomMostConst: CGFloat = min(vc.isRemovalInteractionEnabled ? positionY(for: .hidden) : bottomY,
                                           surfaceView.superview!.bounds.height)
        let minConst = allowsTopBuffer ? topMostConst - topInteractionBuffer : topMostConst
        let maxConst = bottomMostConst + bottomInteractionBuffer

        var const = initialConst + diff

        // Rubberbanding top buffer
        if behavior.allowsRubberBanding?(for: .top) ?? false, const < topMostConst {
            let buffer = topMostConst - const
            const = topMostConst - rubberbandEffect(for: buffer, base: vc.view.bounds.height)
        }

        // Rubberbanding bottom buffer
        if behavior.allowsRubberBanding?(for: .bottom) ?? false, const > bottomMostConst {
            let buffer = const - bottomMostConst
            const = bottomMostConst + rubberbandEffect(for: buffer, base: vc.view.bounds.height)
        }

        interactiveEdgeConstraint?.constant = max(minConst, min(maxConst, const))
    }

    // According to @chpwn's tweet: https://twitter.com/chpwn/status/285540192096497664
    // x = distance from the edge
    // c = constant value, UIScrollView uses 0.55
    // d = dimension, either width or height
    private func rubberbandEffect(for buffer: CGFloat, base: CGFloat) -> CGFloat {
        return (1.0 - (1.0 / ((buffer * 0.55 / base) + 1.0))) * base
    }

    func activateFixedLayout() {
        // Must deactivate `interactiveTopConstraint` here
        NSLayoutConstraint.deactivate(constraint: self.interactiveEdgeConstraint)
        self.interactiveEdgeConstraint = nil

        NSLayoutConstraint.activate(fixedConstraints)

        if vc.contentMode == .fitToBounds {
            NSLayoutConstraint.activate(constraint: self.fitToBoundsConstraint)
        }
    }

    func activateInteractiveLayout(of state: FloatingPanelState) {
        defer {
            layoutSurfaceIfNeeded()
            log.debug("activateLayout -- surface.presentation = \(self.surfaceView.presentationFrame) surface.frame = \(self.surfaceView.frame)")
        }

        var state = state

        setBackdropAlpha(of: state)

        if isValid(state) == false {
            state = layout.initialState
        }

        NSLayoutConstraint.deactivate(fullConstraints + halfConstraints + tipConstraints + offConstraints)
        switch state {
        case .full:
            NSLayoutConstraint.activate(fullConstraints)
        case .half:
            NSLayoutConstraint.activate(halfConstraints)
        case .tip:
            NSLayoutConstraint.activate(tipConstraints)
        case .hidden:
            NSLayoutConstraint.activate(offConstraints)
        default:
            break
        }
    }

    func activateLayout(of state: FloatingPanelState) {
        activateFixedLayout()
        activateInteractiveLayout(of: state)
    }

    func isValid(_ state: FloatingPanelState) -> Bool {
        return supportedPositions.union([.hidden]).contains(state)
    }

    private func layoutSurfaceIfNeeded() {
        #if !TEST
        guard surfaceView.window != nil else { return }
        #endif
        surfaceView.superview?.layoutIfNeeded()
    }

    private func setBackdropAlpha(of target: FloatingPanelState) {
        if target == .hidden {
            self.backdropView.alpha = 0.0
        } else {
            self.backdropView.alpha = backdropAlpha(for: target)
        }
    }

    func backdropAlpha(for state: FloatingPanelState) -> CGFloat {
        return layout.backdropAlpha?(for: state) ?? defaultLayout.backdropAlpha(for: state)
    }

    func checkLayoutConsistance() {
        // Verify layout configurations
        assert(supportedPositions.count > 0)
        assert(supportedPositions.contains(layout.initialState),
               "Does not include an initial position (\(layout.initialState)) in supportedPositions (\(supportedPositions))")
        let statePosOrder = supportedPositions.sorted(by: { positionY(for: $0) < positionY(for: $1) })
        assert(sortedDirectionalPositions == statePosOrder,
               "Check your layout anchors because the state position's order(\(statePosOrder)) must be (\(sortedDirectionalPositions))).")
    }

    // TODO: Support interactive bottom edge
    func segument(at posY: CGFloat, forward: Bool) -> LayoutSegment {
        /// ----------------------->Y
        /// --> forward                <-- backward
        /// |-------|===o===|-------|  |-------|-------|===o===|
        /// |-------|-------x=======|  |-------|=======x-------|
        /// |-------|-------|===o===|  |-------|===o===|-------|
        /// pos: o/x, seguement: =

        let sortedPositions = sortedDirectionalPositions

        let upperIndex: Int?
        if forward {
            #if swift(>=4.2)
            upperIndex = sortedPositions.firstIndex(where: { posY < positionY(for: $0) })
            #else
            upperIndex = sortedPositions.index(where: { posY < positionY(for: $0) })
            #endif
        } else {
            #if swift(>=4.2)
            upperIndex = sortedPositions.firstIndex(where: { posY <= positionY(for: $0) })
            #else
            upperIndex = sortedPositions.index(where: { posY <= positionY(for: $0) })
            #endif
        }

        switch upperIndex {
        case 0:
            return LayoutSegment(lower: nil, upper: sortedPositions.first)
        case let upperIndex?:
            return LayoutSegment(lower: sortedPositions[upperIndex - 1], upper: sortedPositions[upperIndex])
        default:
            return LayoutSegment(lower: sortedPositions[sortedPositions.endIndex - 1], upper: nil)
        }
    }
}
