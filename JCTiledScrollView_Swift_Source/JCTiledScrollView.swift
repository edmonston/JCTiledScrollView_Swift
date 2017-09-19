//
//  Copyright (c) 2017-present Peter Edmonston
//  https://github.com/edmonston
//
//  This source code is licensed under MIT license found in the LICENSE file
//  in the root directory of this source tree.
//  Attribution can be found in the ATTRIBUTION file in the root directory 
//  of this source tree.
//

import UIKit

let kJCTiledScrollViewAnimationTime = TimeInterval(0.1)

@objc protocol JCTiledScrollViewDelegate: NSObjectProtocol {
    func tiledScrollView(_ scrollView: JCTiledScrollView!, viewForAnnotation annotation: JCAnnotation) -> JCAnnotationView?

    @objc optional func tiledScrollViewDidZoom(_ scrollView: JCTiledScrollView)
    @objc optional func tiledScrollViewDidScroll(_ scrollView: JCTiledScrollView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationWillDisappear annotation: JCAnnotation)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationDidDisappear annotation: JCAnnotation)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationWillAppear annotation: JCAnnotation)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationDidAppear annotation: JCAnnotation)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, shouldSelectAnnotationView view: JCAnnotationView) -> Bool
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, didSelectAnnotationView view: JCAnnotationView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, didDeselectAnnotationView view: JCAnnotationView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, didReceiveSingleTap gestureRecognizer: UIGestureRecognizer)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, didReceiveDoubleTap gestureRecognizer: UIGestureRecognizer)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, didReceiveTwoFingerTap gestureRecognizer: UIGestureRecognizer)
}

@objc protocol JCTileSource: NSObjectProtocol {
    func tiledScrollView(_ scrollView: JCTiledScrollView, imageForRow row: Int, column: Int, scale: Int) -> UIImage?
}

@objc class JCTiledScrollView: UIView {
    //Delegates
    weak var tiledScrollViewDelegate: JCTiledScrollViewDelegate?
    weak var dataSource: JCTileSource?

    //Views
    lazy var tiledView: JCTiledView = {
        let tiledView = type(of: self).tiledViewClass().init()
        return tiledView
    }()
    
    let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .white
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.minimumZoomScale = 1.0
        return scrollView
    }()
    
    fileprivate let canvasView: UIView = {
        let canvasView = UIView()
        canvasView.isUserInteractionEnabled = false
        return canvasView
    }()

    //Default gesture behvaiour
    var centerSingleTap = true
    var zoomsInOnDoubleTap = true
    var zoomsToTouchLocation = false
    var zoomsOutOnTwoFingerTap = true

    var levelsOfZoom: UInt = 2 {
        didSet {
            scrollView.maximumZoomScale = pow(2.0, max(0.0, CGFloat(levelsOfZoom)))
        }
    }
    var levelsOfDetail: UInt = 2 {
        didSet  {
            if levelsOfDetail == 1 {
                print("Note: Setting levelsOfDetail to 1 causes strange behaviour")
            }
            tiledView.numberOfZoomLevels = size_t(levelsOfDetail)
        }
    }
    var zoomScale: CGFloat {
        set {
            setZoomScale(newValue, animated: false)
        }
        get {
            return scrollView.zoomScale
        }
    }
    
    var muteAnnotationUpdates: Bool  = false{
        didSet {
            // FIXME: Jesse C - I don't like overloading this here, but the logic is in one place

            isUserInteractionEnabled = !self.muteAnnotationUpdates
            if !muteAnnotationUpdates {
                correctScreenPositionOfAnnotations()
            }
        }
    }

    fileprivate var annotations = Set<JCAnnotation>()
    fileprivate var recycledAnnotationViews = Set<JCAnnotationView>()
    fileprivate var visibleAnnotations = Set<JCVisibleAnnotationTuple>()
    fileprivate var previousSelectedAnnotationTuple: JCVisibleAnnotationTuple?
    fileprivate var currentSelectedAnnotationTuple: JCVisibleAnnotationTuple?

    private lazy var singleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = JCAnnotationTapGestureRecognizer(target: self, action: #selector(JCTiledScrollView.singleTapReceived))
        gestureRecognizer.numberOfTapsRequired = 1
        gestureRecognizer.delegate = self
        return gestureRecognizer
    }()
    
    private lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(JCTiledScrollView.doubleTapReceived))
        gestureRecognizer.numberOfTapsRequired = 2
        return gestureRecognizer
    }()
    
    private lazy var twoFingerTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(JCTiledScrollView.twoFingerTapReceived))
        gestureRecognizer.numberOfTouchesRequired = 2
        gestureRecognizer.numberOfTapsRequired = 1
        return gestureRecognizer
    }()

    // MARK: -

    // MARK: Init method and main methods
    init(frame: CGRect, contentSize: CGSize) {
        super.init(frame: frame)

        autoresizingMask = [.flexibleHeight, .flexibleWidth]

        scrollView.delegate = self
        tiledView.delegate = self
        
        canvasView.setFixedSize(contentSize)
        tiledView.setFixedSize(contentSize)
       
        addSubview(scrollView, insets: .zero)
        scrollView.addSubview(tiledView, insets: .zero)
        addSubview(canvasView)
        
        tiledView.addGestureRecognizer(singleTapGestureRecognizer)
        tiledView.addGestureRecognizer(doubleTapGestureRecognizer)
        tiledView.addGestureRecognizer(twoFingerTapGestureRecognizer)
        singleTapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func tiledViewClass() -> JCTiledView.Type {
        return JCTiledView.self
    }

    // MARK: Position
    
    fileprivate func correctScreenPositionOfAnnotations() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.0)
        if (scrollView.isZoomBouncing || muteAnnotationUpdates) && !scrollView.isZooming {
            visibleAnnotations.forEach { $0.view.position = screenPosition(for: $0.annotation) }
        } else {
            for annotation in annotations {
                let position = screenPosition(for: annotation)
                let t = visibleAnnotations.visibleAnnotationTuple(for: annotation)
                if position.jc_isWithinBounds(bounds) {
                    if let t = t {
                        if t == currentSelectedAnnotationTuple {
                            canvasView.addSubview(t.view)
                        }
                        t.view.position = position
                    } else if let view = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) {
                        view.position = position
                        let t = JCVisibleAnnotationTuple(annotation: annotation, view: view)
                        tiledScrollViewDelegate?.tiledScrollView?(self, annotationWillAppear: t.annotation)
                        visibleAnnotations.insert(t)
                        canvasView.addSubview(t.view)
                        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
                        let animation = CABasicAnimation(keyPath: "opacity")
                        animation.duration = 0.3
                        animation.repeatCount = 1
                        animation.fromValue = 0.0
                        animation.toValue = 1.0
                        t.view.layer.add(animation, forKey: "animateOpacity")
                        tiledScrollViewDelegate?.tiledScrollView?(self, annotationDidAppear: t.annotation)
                    } else {
                        // view is nil
                        continue
                    }
                } else {
                    if let t = t {
                        tiledScrollViewDelegate?.tiledScrollView?(self, annotationWillAppear: t.annotation)
                        if t != currentSelectedAnnotationTuple {
                            t.view.removeFromSuperview()
                            recycledAnnotationViews.insert(t.view)
                            visibleAnnotations.remove(t)
                        } else {
                            // FIXME: Anthony D - I don't like let the view in visible annotations array, but the logic is in one place
                            t.view.removeFromSuperview()
                        }
                        tiledScrollViewDelegate?.tiledScrollView?(self, annotationDidDisappear: t.annotation)
                    }
                } // if screenPosition.jc_isWithinBounds(bounds)
            } // for obj in annotations
        }// if (scrollView.zoomBouncing || muteAnnotationUpdates) && !scrollView.zooming
        CATransaction.commit()
    }

    private func screenPosition(for annotation: JCAnnotation) -> CGPoint {
        var position = CGPoint.zero
        position.x = (annotation.contentPosition.x * zoomScale) - scrollView.contentOffset.x
        position.y = (annotation.contentPosition.y * zoomScale) - scrollView.contentOffset.y
        return position
    }

    // MARK: Mute Annotation Updates
    func makeMuteAnnotationUpdatesTrueForTime(_ time: TimeInterval) {
        muteAnnotationUpdates = true
        let popTime = DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime) { [weak self] in
            self?.muteAnnotationUpdates = false
        }
    }

    // MARK: JCTiledScrollView
    func setZoomScale(_ zoomScale: CGFloat, animated: Bool) {
        scrollView.setZoomScale(zoomScale, animated: animated)
    }

    func setContentCenter(_ center: CGPoint, animated: Bool) {
        scrollView.jc_setContentCenter(center, animated: animated)
    }

    // MARK: Annotation Recycling

    func dequeueReusableAnnotationViewWithReuseIdentifier(_ reuseIdentifier: String) -> JCAnnotationView? {
        if let view = recycledAnnotationViews.first(where: { $0.reuseIdentifier == reuseIdentifier }) {
            recycledAnnotationViews.remove(view)
            return view
        }
        return nil
    }

    // MARK: Annotations

    func refreshAnnotations() {
        correctScreenPositionOfAnnotations()
        annotations.flatMap { visibleAnnotations.visibleAnnotationTuple(for: $0) }.forEach { t in
            t.view.setNeedsLayout()
            t.view.setNeedsDisplay()
        }
    }

    func addAnnotation(_ annotation: JCAnnotation) {
        annotations.insert(annotation)
        let position = screenPosition(for: annotation)
        guard position.jc_isWithinBounds(bounds),
            let view = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) else { return }
        view.position = position
        visibleAnnotations.insert(JCVisibleAnnotationTuple(annotation: annotation, view: view))
        canvasView.addSubview(view)
    }

    func addAnnotations(_ annotations: [JCAnnotation]) {
        annotations.forEach { addAnnotation($0) }
    }

    func removeAnnotation(_ annotation: JCAnnotation) {
        guard annotations.contains(annotation) else { return }
        if let t = visibleAnnotations.visibleAnnotationTuple(for: annotation) {
            t.view.removeFromSuperview()
            visibleAnnotations.remove(t)
        }
        annotations.remove(annotation)
    }

    func removeAnnotations(_ annotations: [JCAnnotation]) {
        annotations.forEach { removeAnnotation($0) }
    }

    func removeAllAnnotations() {
        removeAnnotations(Array(annotations))
    }

}

// MARK: - UIScrollViewDelegate

extension JCTiledScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return tiledView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        tiledScrollViewDelegate?.tiledScrollViewDidZoom?(self)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        correctScreenPositionOfAnnotations()
        tiledScrollViewDelegate?.tiledScrollViewDidScroll?(self)
    }
}

// MARK: - JCTiledBitmapViewDelegate

extension JCTiledScrollView: JCTiledViewDelegate {
    func tiledView(_ tiledView: JCTiledView, imageForRow row: Int, column: Int, scale: Int) -> UIImage? {
        return dataSource?.tiledScrollView(self, imageForRow: row, column: column, scale: scale)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension JCTiledScrollView: UIGestureRecognizerDelegate {

    @objc fileprivate func singleTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.isKind(of: JCAnnotationTapGestureRecognizer.self) {

            guard let annotationGestureRecognizer = gestureRecognizer as? JCAnnotationTapGestureRecognizer else { return }
            previousSelectedAnnotationTuple = currentSelectedAnnotationTuple
            currentSelectedAnnotationTuple = annotationGestureRecognizer.tapAnnotation

            if annotationGestureRecognizer.tapAnnotation == nil {
                if let previousSelectedAnnotationTuple = previousSelectedAnnotationTuple {
                    tiledScrollViewDelegate?.tiledScrollView?(self, didDeselectAnnotationView: previousSelectedAnnotationTuple.view)
                }
                else if centerSingleTap {
                    setContentCenter(gestureRecognizer.location(in: tiledView), animated: true)
                }
                tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveSingleTap: gestureRecognizer)
            } else {
                if let previousSelectedAnnotationTuple = previousSelectedAnnotationTuple {
                    tiledScrollViewDelegate?.tiledScrollView?(self, didDeselectAnnotationView: previousSelectedAnnotationTuple.view)
                }
                if currentSelectedAnnotationTuple != nil {
                    if let tapAnnotation = annotationGestureRecognizer.tapAnnotation {
                        let currentSelectedAnnotationView = tapAnnotation.view
                        if (tiledScrollViewDelegate?.tiledScrollView?(self, shouldSelectAnnotationView: currentSelectedAnnotationView) ?? true) == true {
                            tiledScrollViewDelegate?.tiledScrollView?(self, didSelectAnnotationView: currentSelectedAnnotationView)
                        } else {
                            tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveSingleTap: gestureRecognizer)
                        }
                    }
                }
            }
        }
    }

    @objc fileprivate func doubleTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        if self.zoomsInOnDoubleTap {
            let newZoom = scrollView.jc_zoomScaleByZoomingIn(1.0)
            makeMuteAnnotationUpdatesTrueForTime(kJCTiledScrollViewAnimationTime)

            if zoomsToTouchLocation {
                let bounds = scrollView.bounds
                let pointInView = gestureRecognizer.location(in: scrollView).applying(CGAffineTransform(scaleX: 1 / scrollView.zoomScale, y: 1 / scrollView.zoomScale))
                let newSize = bounds.size.applying(CGAffineTransform(scaleX: 1 / newZoom, y: 1 / newZoom))
                scrollView.zoom(to: CGRect(x: pointInView.x - (newSize.width / 2),
                                           y: pointInView.y - (newSize.height / 2),
                                           width: newSize.width,
                                           height: newSize.height),
                                animated: true)
            } else {
                scrollView.setZoomScale(newZoom, animated: true)
            }
        }
        tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveDoubleTap: gestureRecognizer)
    }

    func twoFingerTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        if zoomsOutOnTwoFingerTap {
            let newZoom = scrollView.jc_zoomScaleByZoomingOut(1.0)
            makeMuteAnnotationUpdatesTrueForTime(kJCTiledScrollViewAnimationTime)
            scrollView.setZoomScale(newZoom, animated: true)
        }
        tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveTwoFingerTap: gestureRecognizer)
    }

    /** Catch our own tap gesture if it is on an annotation view to set annotation.
     *Return NO to only recognize single tap on annotation
     */

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let location = gestureRecognizer.location(in: canvasView)
        (gestureRecognizer as? JCAnnotationTapGestureRecognizer)?.tapAnnotation = nil
        for t in self.visibleAnnotations {
            if t.view.frame.contains(location) {
                (gestureRecognizer as? JCAnnotationTapGestureRecognizer)?.tapAnnotation = t
                return true
            }
        }

        // Deal with all tap gesture
        return true
    }
}
