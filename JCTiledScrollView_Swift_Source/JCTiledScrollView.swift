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
    func tiledScrollView(_ scrollView: JCTiledScrollView, viewForAnnotation annotation: JCAnnotation) -> JCAnnotationView?

    @objc optional func tiledScrollViewDidZoom(_ scrollView: JCTiledScrollView)
    @objc optional func tiledScrollViewDidScroll(_ scrollView: JCTiledScrollView)
    
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationViewWillDisappear annotation: JCAnnotationView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationViewDidDisappear annotation: JCAnnotationView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationViewWillAppear annotation: JCAnnotationView)
    @objc optional func tiledScrollView(_ scrollView: JCTiledScrollView, annotationViewDidAppear annotation: JCAnnotationView)
    
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
        return type(of: self).tiledViewClass().init()
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

    var levelsOfZoom = 2 {
        didSet {
            scrollView.maximumZoomScale = pow(2.0, max(0.0, CGFloat(levelsOfZoom)))
        }
    }
    
    var levelsOfDetail = 2 {
        didSet  {
            if levelsOfDetail == 1 {
                print("Note: Setting levelsOfDetail to 1 causes strange behaviour")
            }
            tiledView.numberOfZoomLevels = levelsOfDetail
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

            isUserInteractionEnabled = !muteAnnotationUpdates
            if !muteAnnotationUpdates {
                correctScreenPositionOfAnnotations()
            }
        }
    }

    fileprivate var annotations = Set<JCAnnotation>()
    fileprivate var recycledAnnotationViews = Set<JCAnnotationView>()
    fileprivate var visibleAnnotationViews = Set<JCAnnotationView>()
    fileprivate var selectedAnnotationView: JCAnnotationView?

    fileprivate func visibleView(for annotation: JCAnnotation) -> JCAnnotationView? {
        return visibleAnnotationViews.first { $0.annotation?.identifier == annotation.identifier }
    }
    
    fileprivate func move(_ annotationView: JCAnnotationView, to position: CGPoint) {
        annotationView.position = position
    }
    
    fileprivate func add(_ annotationView: JCAnnotationView, at position: CGPoint) {
        assert(annotationView.annotation != nil, "Visible views must have a non-nil annotation")
        
        tiledScrollViewDelegate?.tiledScrollView?(self, annotationViewWillAppear: annotationView)
        canvasView.addSubview(annotationView)
        visibleAnnotationViews.insert(annotationView)
        annotationView.position = position
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.duration = 0.3
        animation.repeatCount = 1
        animation.fromValue = 0.0
        animation.toValue = 1.0
        annotationView.layer.add(animation, forKey: "animateOpacity")
        tiledScrollViewDelegate?.tiledScrollView?(self, annotationViewDidAppear: annotationView)
    }
    
    fileprivate func remove(_ annotationView: JCAnnotationView) {
        assert(annotationView.annotation != nil, "Visible views must have a non-nil annotation")

        tiledScrollViewDelegate?.tiledScrollView?(self, annotationViewWillDisappear: annotationView)
        visibleAnnotationViews.remove(annotationView)
        recycledAnnotationViews.insert(annotationView)
        annotationView.removeFromSuperview()
        tiledScrollViewDelegate?.tiledScrollView?(self, annotationViewDidDisappear: annotationView)
    }
    
    
    private lazy var singleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(JCTiledScrollView.singleTapReceived))
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
            visibleAnnotationViews.forEach { view in
                guard let annotation = view.annotation else { return }
                view.position = screenPosition(for: annotation)
            }
        } else {
            for annotation in annotations {
                let newPosition = screenPosition(for: annotation)
                let alreadyVisibleView = visibleView(for: annotation)
                let isVisible = newPosition.isInside(bounds, insetBy: -25)
                switch (alreadyVisibleView, isVisible) {
                case (let annotationView?, true):
                    move(annotationView, to: newPosition)
                case (let annotationView?, false):
                    remove(annotationView)
                case (nil, true):
                    if let annotationView = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) {
                        add(annotationView, at: newPosition)
                    }
                case (nil, false): break
                }
            }
        }
        CATransaction.commit()
    }

    private func screenPosition(for annotation: JCAnnotation) -> CGPoint {
        var position = CGPoint.zero
        position.x = (annotation.contentPosition.x * zoomScale) - scrollView.contentOffset.x
        position.y = (annotation.contentPosition.y * zoomScale) - scrollView.contentOffset.y
        return position
    }

    fileprivate func makeMuteAnnotationUpdatesTrueForTime(_ time: TimeInterval) {
        muteAnnotationUpdates = true
        let popTime = DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime) { [weak self] in
            self?.muteAnnotationUpdates = false
        }
    }

    // MARK: - Public Methods

    func setZoomScale(_ zoomScale: CGFloat, animated: Bool) {
        scrollView.setZoomScale(zoomScale, animated: animated)
    }
    
    func setContentCenter(_ center: CGPoint, animated: Bool) {
        scrollView.jc_setContentCenter(center, animated: animated)
    }

    func dequeueReusableAnnotationViewWithReuseIdentifier(_ reuseIdentifier: String) -> JCAnnotationView? {
        guard let view = recycledAnnotationViews.first(where: { $0.reuseIdentifier == reuseIdentifier }) else { return nil }
        return recycledAnnotationViews.remove(view)
    }

    func refreshAnnotations() {
        correctScreenPositionOfAnnotations()
    }

    func addAnnotation(_ annotation: JCAnnotation) {
        annotations.insert(annotation)
        let position = screenPosition(for: annotation)
        guard position.isInside(bounds, insetBy: -25),
            let view = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) else { return }
        add(view, at: position)
    }

    func addAnnotations(_ annotations: [JCAnnotation]) {
        annotations.forEach { addAnnotation($0) }
    }

    func removeAnnotation(_ annotation: JCAnnotation) {
        guard let annotationToRemove = annotations.remove(annotation) else { return }
        guard let annotationViewToRemove = visibleView(for: annotationToRemove) else { return }
        remove(annotationViewToRemove)
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
        let newlyTappedAnnotationView = visibleAnnotationViews.first { annotationView in
            annotationView.point(inside: gestureRecognizer.location(in: annotationView), with: nil)
        }
        
        let previouslySelectedAnnotationView = selectedAnnotationView
        selectedAnnotationView = newlyTappedAnnotationView
        var selectionBlocked = false
        
        if let annotationView = newlyTappedAnnotationView {
            if tiledScrollViewDelegate?.tiledScrollView?(self, shouldSelectAnnotationView: annotationView) ?? true {
                tiledScrollViewDelegate?.tiledScrollView?(self, didSelectAnnotationView: annotationView)
            } else {
                selectionBlocked = true
            }
        }
        if let annotationView = previouslySelectedAnnotationView {
            tiledScrollViewDelegate?.tiledScrollView?(self, didDeselectAnnotationView: annotationView)
        }
        if newlyTappedAnnotationView == nil || selectionBlocked {
            if centerSingleTap {
                setContentCenter(gestureRecognizer.location(in: tiledView), animated: true)
            }
            tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveSingleTap: gestureRecognizer)
        }
    }
    
    @objc fileprivate func doubleTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        if zoomsInOnDoubleTap {
            let newZoom = scrollView.jc_zoomScaleByZoomingIn(1.0)
            makeMuteAnnotationUpdatesTrueForTime(kJCTiledScrollViewAnimationTime)

            if zoomsToTouchLocation {
                let bounds = scrollView.bounds
                let transform = CGAffineTransform(scaleX: 1 / scrollView.zoomScale, y: 1 / scrollView.zoomScale)
                let pointInView = gestureRecognizer.location(in: scrollView).applying(transform)
                let newSize = bounds.size.applying(CGAffineTransform(scaleX: 1 / newZoom, y: 1 / newZoom))
                let zoomRect = CGRect(x: pointInView.x - (newSize.width / 2),
                                      y: pointInView.y - (newSize.height / 2),
                                      width: newSize.width,
                                      height: newSize.height)
                scrollView.zoom(to: zoomRect, animated: true)
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
}
