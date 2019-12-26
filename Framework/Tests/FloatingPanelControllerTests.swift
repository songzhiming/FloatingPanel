//
//  Created by Shin Yamamoto on 2018/09/18.
//  Copyright © 2018 Shin Yamamoto. All rights reserved.
//

import XCTest
@testable import FloatingPanel

class FloatingPanelControllerTests: XCTestCase {
    override func setUp() {}
    override func tearDown() {}

    func test_warningRetainCycle() {
        let exp = expectation(description: "Warning retain cycle")
        exp.expectedFulfillmentCount = 2 // For layout & behavior logs
        log.hook = {(log, level) in
            if log.contains("A memory leak will occur by a retain cycle because") {
                XCTAssert(level == .warning)
                exp.fulfill()
            }
        }
        let myVC = MyZombieViewController(nibName: nil, bundle: nil)
        myVC.loadViewIfNeeded()
        wait(for: [exp], timeout: 10)
    }

    func test_addPanel() {
        guard let rootVC = UIApplication.shared.keyWindow?.rootViewController else { fatalError() }
        let fpc = FloatingPanelController()
        fpc.addPanel(toParent: rootVC)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .half).y)
        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .tip).y)
    }

    @available(iOS 12.0, *)
    func test_updateLayout_willTransition() {
        class MyDelegate: FloatingPanelControllerDelegate {
            func floatingPanel(_ vc: FloatingPanelController, layoutFor newCollection: UITraitCollection) -> FloatingPanelLayout? {
                if newCollection.userInterfaceStyle == .dark {
                    XCTFail()
                }
                return nil
            }
        }
        let myDelegate = MyDelegate()
        let fpc = FloatingPanelController(delegate: myDelegate)
        let traitCollection = UITraitCollection(traitsFrom: [fpc.traitCollection,
                                                             UITraitCollection(userInterfaceStyle: .dark)])
        XCTAssertEqual(traitCollection.userInterfaceStyle, .dark)
    }

    func test_moveTo() {
        let delegate = FloatingPanelTestDelegate()
        let fpc = FloatingPanelController(delegate: delegate)
        XCTAssertEqual(delegate.position, .hidden)
        fpc.showForTest()
        XCTAssertEqual(delegate.position, .half)

        fpc.hide()
        XCTAssertEqual(delegate.position, .hidden)
        
        fpc.move(to: .full, animated: false)
        XCTAssertEqual(fpc.state, .full)
        XCTAssertEqual(delegate.position, .full)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .full).y)

        fpc.move(to: .half, animated: false)
        XCTAssertEqual(fpc.state, .half)
        XCTAssertEqual(delegate.position, .half)

        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .half))

        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.state, .tip)
        XCTAssertEqual(delegate.position, .tip)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .tip).y)

        fpc.move(to: .hidden, animated: false)
        XCTAssertEqual(fpc.state, .hidden)
        XCTAssertEqual(delegate.position, .hidden)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .hidden).y)

        fpc.move(to: .full, animated: true)
        XCTAssertEqual(fpc.state, .full)
        XCTAssertEqual(delegate.position, .full)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .full).y)

        fpc.move(to: .half, animated: true)
        XCTAssertEqual(fpc.state, .half)
        XCTAssertEqual(delegate.position, .half)
        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .half))

        fpc.move(to: .tip, animated: true)
        XCTAssertEqual(fpc.state, .tip)
        XCTAssertEqual(delegate.position, .tip)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .tip).y)

        fpc.move(to: .hidden, animated: true)
        XCTAssertEqual(fpc.state, .hidden)
        XCTAssertEqual(delegate.position, .hidden)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .hidden).y)
    }

    func test_moveTo_bottomEdge() {
        class MyFloatingPanelTop2BottomLayout: FloatingPanelTop2BottomTestLayout {
            override var initialState: FloatingPanelState { return .half }
        }
        let delegate = FloatingPanelTestDelegate()
        let fpc = FloatingPanelController(delegate: delegate)
        fpc.layout = MyFloatingPanelTop2BottomLayout()
        XCTAssertEqual(delegate.position, .hidden)
        fpc.showForTest()
        XCTAssertEqual(delegate.position, .half)

        fpc.hide()
        XCTAssertEqual(delegate.position, .hidden)

        fpc.move(to: .full, animated: false)
        XCTAssertEqual(fpc.state, .full)
        XCTAssertEqual(delegate.position, .full)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .full).y)

        fpc.move(to: .half, animated: false)
        XCTAssertEqual(fpc.state, .half)
        XCTAssertEqual(delegate.position, .half)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .half).y)

        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.state, .tip)
        XCTAssertEqual(delegate.position, .tip)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .tip).y)

        fpc.move(to: .hidden, animated: false)
        XCTAssertEqual(fpc.state, .hidden)
        XCTAssertEqual(delegate.position, .hidden)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .hidden).y)

        fpc.move(to: .full, animated: true)
        XCTAssertEqual(fpc.state, .full)
        XCTAssertEqual(delegate.position, .full)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .full).y)

        fpc.move(to: .half, animated: true)
        XCTAssertEqual(fpc.state, .half)
        XCTAssertEqual(delegate.position, .half)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .half).y)

        fpc.move(to: .tip, animated: true)
        XCTAssertEqual(fpc.state, .tip)
        XCTAssertEqual(delegate.position, .tip)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .tip).y)

        fpc.move(to: .hidden, animated: true)
        XCTAssertEqual(fpc.state, .hidden)
        XCTAssertEqual(delegate.position, .hidden)
        XCTAssertEqual(fpc.surfaceEdgePosition.y, fpc.surfaceEdgePosition(for: .hidden).y)
    }

    func test_originSurfaceY() {
        let fpc = FloatingPanelController(delegate: nil)
        fpc.loadViewIfNeeded()
        fpc.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        fpc.show(animated: false, completion: nil)

        fpc.move(to: .full, animated: false)
        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .full))
        fpc.move(to: .half, animated: false)
        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .half))
        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .tip))
        fpc.move(to: .hidden, animated: false)
        XCTAssertEqual(fpc.surfaceEdgePosition, fpc.surfaceEdgePosition(for: .hidden))
    }

    func test_contentMode() {
        let fpc = FloatingPanelController(delegate: nil)
        fpc.loadViewIfNeeded()
        fpc.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        fpc.show(animated: false, completion: nil)

        fpc.contentMode = .static

        fpc.move(to: .full, animated: false)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .full).y)
        fpc.move(to: .half, animated: false)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .full).y)
        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .full).y)

        fpc.contentMode = .fitToBounds

        fpc.move(to: .full, animated: false)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .full).y)
        fpc.move(to: .half, animated: false)
        print(1 / fpc.surfaceView.traitCollection.displayScale)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .half).y)
        fpc.move(to: .tip, animated: false)
        XCTAssertEqual(fpc.surfaceView.frame.height, fpc.view.bounds.height - fpc.surfaceEdgePosition(for: .tip).y)
    }
}

private class MyZombieViewController: UIViewController, FloatingPanelLayout, FloatingPanelBehavior, FloatingPanelControllerDelegate {
    var fpc: FloatingPanelController?
    override func viewDidLoad() {
        fpc = FloatingPanelController(delegate: self)
        fpc?.addPanel(toParent: self)
        fpc?.layout = self
        fpc?.behavior = self
    }
    var position: FloatingPanelPosition {
        return .bottom
    }
    var initialState: FloatingPanelState {
        return .half
    }

    var layoutAnchors: [FloatingPanelState : FloatingPanelLayoutAnchoring] {
        return [
            .full: FloatingPanelLayoutAnchor(absoluteOffset: UIScreen.main.bounds.height == 667.0 ? 18.0 : 16.0,
                                             referenceGuide: .superview, from: .top),
            .half: FloatingPanelLayoutAnchor(absoluteOffset: 250.0,
                                             referenceGuide: .superview, from: .bottom),
            .tip: FloatingPanelLayoutAnchor(absoluteOffset: 60.0,
                                            referenceGuide: .superview, from: .bottom),
        ]
    }
}
