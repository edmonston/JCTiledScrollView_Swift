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

@objc public protocol JCTiledScrollViewDelegate: NSObjectProtocol {
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

@objc public protocol JCTileSource: NSObjectProtocol {
    func tiledScrollView(_ scrollView: JCTiledScrollView, imageForRow row: Int, column: Int, scale: Int) -> UIImage?
}

@objc public class JCTiledScrollView: UIView {
    //Delegates
    public weak var tiledScrollViewDelegate: JCTiledScrollViewDelegate?
    public weak var dataSource: JCTileSource?

    //Views
    lazy var tiledView: JCTiledView = {
        return type(of: self).tiledViewClass().init()
    }()
    
    public let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .white
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.minimumZoomScale = 1.0
        return scrollView
    }()
    
    public var tiledViewSize: CGSize {
        return tiledView.bounds.size
    }
    
    fileprivate let canvasView: UIView = {
        let canvasView = UIView()
        canvasView.isUserInteractionEnabled = false
        return canvasView
    }()

    //Default gesture behvaiour

    public var centerSingleTap = true
    public var zoomsInOnDoubleTap = true
    public var zoomsToTouchLocation = false
    public var zoomsOutOnTwoFingerTap = true
    public var tapRequiresDoubleTapToFail = false

    public var annotatesRect: Bool {
        get { return tiledView.shouldAnnotateRect }
        set { tiledView.shouldAnnotateRect = newValue }
    }
    
    public var levelsOfZoom = 2 {
        didSet {
            scrollView.maximumZoomScale = pow(2.0, max(0.0, CGFloat(levelsOfZoom)))
        }
    }
    
    public var levelsOfDetail = 2 {
        didSet  {
            if levelsOfDetail == 1 {
                print("Note: Setting levelsOfDetail to 1 causes strange behaviour")
            }
            tiledView.numberOfZoomLevels = levelsOfDetail
        }
    }
    
    public var zoomScale: CGFloat {
        set { setZoomScale(newValue, animated: false) }
        get { return scrollView.zoomScale }
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
    
    fileprivate (set) public var annotations = Set<JCAnnotation>()
    
    fileprivate var recycledAnnotationViews = Set<JCAnnotationView>()
    fileprivate var visibleAnnotationViews = Set<JCAnnotationView>()
    fileprivate var selectedAnnotationView: JCAnnotationView?
    fileprivate var prerequestedAnnotationViews = [String: JCAnnotationView]()
    
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
    public init(frame: CGRect, contentSize: CGSize) {
        super.init(frame: frame)

        autoresizingMask = [.flexibleHeight, .flexibleWidth]

        scrollView.delegate = self
        tiledView.delegate = self

        tiledView.setFixedSize(contentSize)
       
        addSubview(scrollView, insets: .zero)
        scrollView.addSubview(tiledView, insets: .zero)
        addSubview(canvasView, insets: .zero)
        
        tiledView.addGestureRecognizer(singleTapGestureRecognizer)
        tiledView.addGestureRecognizer(doubleTapGestureRecognizer)
        tiledView.addGestureRecognizer(twoFingerTapGestureRecognizer)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func tiledViewClass() -> JCTiledView.Type {
        return JCTiledView.self
    }

    // MARK: Position
    
    fileprivate func correctScreenPositionOfAnnotations(limitedTo annotationsToUpdate: Set<JCAnnotation>? = nil) {
        if (scrollView.isZoomBouncing || muteAnnotationUpdates) && !scrollView.isZooming {
            visibleAnnotationViews.forEach { view in
                guard let annotation = view.annotation,
                    annotationsToUpdate == nil || annotationsToUpdate?.contains(annotation) == true else { return }
                view.position = screenPosition(for: annotation)
            }
            canvasView.layoutIfNeeded()
        } else {
            for annotation in annotationsToUpdate ?? annotations {
                let newPosition = screenPosition(for: annotation)
                let alreadyVisibleView = visibleView(for: annotation)
                let isVisible = newPosition.isInside(bounds, insetBy: -25)
                switch (alreadyVisibleView, isVisible) {
                case (let annotationView?, true):
                    move(annotationView, to: newPosition)
                case (let annotationView?, false):
                    remove(annotationView)
                case (nil, true):
                    if let annotationView = prerequestedAnnotationViews[annotation.identifier]
                        ?? tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) {
                        add(annotationView, at: newPosition)
                        prerequestedAnnotationViews[annotation.identifier] = nil
                    }
                case (nil, false): break
                }
            }
        }
    }

    private func position(for annotation: JCAnnotation) -> CGPoint {
        return CGPoint(x: annotation.contentPosition.x * zoomScale,
                       y: annotation.contentPosition.y * zoomScale)
    }
    
    private func screenPosition(for annotation: JCAnnotation) -> CGPoint {
        return position(for: annotation) - scrollView.contentOffset
    }

    fileprivate func makeMuteAnnotationUpdatesTrueForTime(_ time: TimeInterval) {
        muteAnnotationUpdates = true
        let popTime = DispatchTime.now() + Double(Int64(time * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime) { [weak self] in
            self?.muteAnnotationUpdates = false
        }
    }

    // MARK: - Public Methods

    public func setZoomScale(_ zoomScale: CGFloat, animated: Bool) {
        scrollView.setZoomScale(zoomScale, animated: animated)
    }
    
    public func setContentCenter(_ center: CGPoint, animated: Bool) {
        scrollView.jc_setContentCenter(center, animated: animated)
    }

    public func dequeueReusableAnnotationViewWithReuseIdentifier(_ reuseIdentifier: String) -> JCAnnotationView? {
        guard let view = recycledAnnotationViews.first(where: { $0.reuseIdentifier == reuseIdentifier }) else { return nil }
        return recycledAnnotationViews.remove(view)
    }

    public func refreshAnnotation(_ annotation: JCAnnotation) {
        correctScreenPositionOfAnnotations(limitedTo: Set([annotation]))
    }
    
    public func refreshAnnotations() {
        correctScreenPositionOfAnnotations()
    }

    public func addAnnotation(_ annotation: JCAnnotation) {
        annotations.insert(annotation)
        let position = screenPosition(for: annotation)
        guard position.isInside(bounds, insetBy: -25),
            let view = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) else { return }
        add(view, at: position)
    }

    public func addAnnotations(_ annotations: [JCAnnotation]) {
        annotations.forEach { addAnnotation($0) }
    }

    public func removeAnnotation(_ annotation: JCAnnotation) {
        guard let annotationToRemove = annotations.remove(annotation) else { return }
        guard let annotationViewToRemove = visibleView(for: annotationToRemove) else { return }
        remove(annotationViewToRemove)
    }

    public func removeAnnotations(_ annotations: [JCAnnotation]) {
        annotations.forEach { removeAnnotation($0) }
    }

    public func removeAllAnnotations() {
        removeAnnotations(Array(annotations))
    }
    
    public func scrollToAnnotation(_ annotation: JCAnnotation, animated: Bool) {
        guard annotations.contains(annotation) else { return }
        let annotationCenter = position(for: annotation)
        let annotationView: UIView
        if let existingView = visibleView(for: annotation) {
            annotationView = existingView
        } else if let newView = tiledScrollViewDelegate?.tiledScrollView(self, viewForAnnotation: annotation) {
            annotationView = newView
            prerequestedAnnotationViews[annotation.identifier] = newView
        } else {
            return
        }
        let annotationSize = annotationView.systemLayoutSizeFitting(UILayoutFittingCompressedSize)
        let origin = CGPoint(x: annotationCenter.x - annotationSize.width / 2.0,
                             y: annotationCenter.y - annotationSize.height / 2.0)
        let rect = CGRect(origin: origin, size: annotationSize)
        scrollView.scrollRectToVisible(rect, animated: animated)
    }
}

// MARK: - UIScrollViewDelegate

extension JCTiledScrollView: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return tiledView
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        tiledScrollViewDelegate?.tiledScrollViewDidZoom?(self)
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
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

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let otherGestureRecognizer = otherGestureRecognizer as? UITapGestureRecognizer,
            otherGestureRecognizer.numberOfTapsRequired == 2 else { return false }
        return tapRequiresDoubleTapToFail
    }
    
    @objc fileprivate func singleTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        let newlyTappedAnnotationView = visibleAnnotationViews.first { annotationView in
            let gestureLocation = gestureRecognizer.location(in: annotationView)
            return annotationView.point(inside: gestureLocation, with: nil)
        }
        let previouslySelectedAnnotationView = selectedAnnotationView
        selectedAnnotationView = newlyTappedAnnotationView
        var selectionBlocked = false
        
        if let annotationView = previouslySelectedAnnotationView {
            tiledScrollViewDelegate?.tiledScrollView?(self, didDeselectAnnotationView: annotationView)
        }
        
        if let annotationView = newlyTappedAnnotationView {
            if tiledScrollViewDelegate?.tiledScrollView?(self, shouldSelectAnnotationView: annotationView) ?? true {
                tiledScrollViewDelegate?.tiledScrollView?(self, didSelectAnnotationView: annotationView)
            } else {
                selectedAnnotationView = nil
                selectionBlocked = true
            }
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

    @objc func twoFingerTapReceived(_ gestureRecognizer: UITapGestureRecognizer) {
        if zoomsOutOnTwoFingerTap {
            let newZoom = scrollView.jc_zoomScaleByZoomingOut(1.0)
            makeMuteAnnotationUpdatesTrueForTime(kJCTiledScrollViewAnimationTime)
            scrollView.setZoomScale(newZoom, animated: true)
        }
        tiledScrollViewDelegate?.tiledScrollView?(self, didReceiveTwoFingerTap: gestureRecognizer)
    }
}

