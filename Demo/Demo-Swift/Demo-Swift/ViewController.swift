//
//  Copyright (c) 2015-present Yichi Zhang
//  https://github.com/yichizhang
//  zhang-yi-chi@hotmail.com
//
//  This source code is licensed under MIT license found in the LICENSE file
//  in the root directory of this source tree.
//  Attribution can be found in the ATTRIBUTION file in the root directory 
//  of this source tree.
//

import UIKit

enum JCDemoType {
    case pdf
    case image
}

let SkippingGirlImageName = "SkippingGirl"
let SkippingGirlImageSize = CGSize(width: 432, height: 648)

let ButtonTitleCancel = "Cancel"
let ButtonTitleRemoveAnnotation = "Remove this Annotation"

@objc class ViewController: UIViewController, JCTiledScrollViewDelegate, JCTileSource, UIAlertViewDelegate
{
    let demoAnnotationViewReuseID = "DemoAnnotationView"

    var scrollView: JCTiledScrollView!
    var infoLabel: UILabel!
    var searchField: UITextField!
    var mode = JCDemoType.pdf
    var annotationsAdded = false

    weak var selectedAnnotation: JCAnnotation?

    override func viewDidLoad()
    {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        switch mode {
        case .pdf: scrollView = JCTiledPDFScrollView(frame: self.view.bounds, URL: Bundle.main.url(forResource: "Map", withExtension: "pdf")!)
        case .image: scrollView = JCTiledScrollView(frame: self.view.bounds, contentSize: SkippingGirlImageSize)
        }

        scrollView.tiledScrollViewDelegate = self
        scrollView.dataSource = self
        scrollView.zoomScale = 1.0
        scrollView.tiledView.shouldAnnotateRect = true

        // totals 4 sets of tiles across all devices, retina devices will miss out on the first 1x set
        scrollView.levelsOfZoom = 3
        scrollView.levelsOfDetail = 3
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        infoLabel = UILabel()
        infoLabel.backgroundColor = .black
        infoLabel.textColor = .white
        infoLabel.textAlignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        view.addConstraints([
                                NSLayoutConstraint(item: scrollView, attribute: .width, relatedBy: .equal, toItem: view, attribute: .width, multiplier: 1, constant: 0),
                                NSLayoutConstraint(item: scrollView, attribute: .height, relatedBy: .equal, toItem: view, attribute: .height, multiplier: 1, constant: 0),
                                NSLayoutConstraint(item: scrollView, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 0),
                                NSLayoutConstraint(item: scrollView, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0),

                                NSLayoutConstraint(item: infoLabel, attribute: .top, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: 20),
                                NSLayoutConstraint(item: infoLabel, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1, constant: 0),
                            ])


    }
    
    var lastScrollViewSize = CGSize.zero
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.layoutIfNeeded()
        if lastScrollViewSize != scrollView.bounds.size {
            defer { lastScrollViewSize = scrollView.bounds.size }
            let horizScale = min(1.0, scrollView.scrollView.contentSize.width / scrollView.bounds.width)
            let vertScale = min(1.0, scrollView.scrollView.contentSize.height / scrollView.bounds.height)
            let minScale = min(horizScale, vertScale)
            if minScale < 1.0 {
                scrollView.scrollView.minimumZoomScale = 1 / minScale
                scrollView.setZoomScale(1 / minScale, animated: false)
            }
        }
        
        guard !annotationsAdded else { return }
        defer { annotationsAdded = true }
     //   scrollView.tiledView.layoutIfNeeded()
        addRandomAnnotations()
        scrollView.refreshAnnotations()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func addRandomAnnotations() {
        for number in 0...8 {
            let randomPoint = scrollView.tiledView.bounds.randomPointInside()
            let annotation = DemoAnnotation(identifier: String(describing: number), contentPosition: randomPoint)
            annotation.isSelectable = (number % 3 != 0)
            scrollView.addAnnotation(annotation)
        }
    }

    // MARK: JCTiledScrollView Delegate
    func tiledScrollViewDidZoom(_ scrollView: JCTiledScrollView) {
        infoLabel.text = NSString(format: "zoomScale=%.2f", scrollView.zoomScale) as String
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, didReceiveSingleTap gestureRecognizer: UIGestureRecognizer) {
        let tapPoint = gestureRecognizer.location(in: scrollView.tiledView)
        infoLabel.text = NSString(format: "(%.2f, %.2f), zoomScale=%.2f", tapPoint.x, tapPoint.y, scrollView.zoomScale) as String
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, shouldSelectAnnotationView view: JCAnnotationView) -> Bool {
        if let annotation = view.annotation as? DemoAnnotation {
            return annotation.isSelectable
        }
        return true
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, didSelectAnnotationView view: JCAnnotationView) {
        guard let annotationView = view as? DemoAnnotationView else {
            return
        }
        let alertView = UIAlertView(
        title: "Annotation Selected",
        message: "You've selected an annotation. What would you like to do with it?",
        delegate: self,
        cancelButtonTitle: ButtonTitleCancel,
        otherButtonTitles: ButtonTitleRemoveAnnotation)
        alertView.show()

        selectedAnnotation = view.annotation
        annotationView.isSelected = true
  //      annotationView.annotation = annotation
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, didDeselectAnnotationView view: JCAnnotationView) {
        guard let annotationView = view as? DemoAnnotationView else {
            return
        }
        selectedAnnotation = nil
        annotationView.isSelected = false
     //   annotationView.annotation = annotation
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, viewForAnnotation annotation: JCAnnotation) -> JCAnnotationView? {
        let annotationView =
        (scrollView.dequeueReusableAnnotationViewWithReuseIdentifier(demoAnnotationViewReuseID) as? DemoAnnotationView) ??
        DemoAnnotationView(frame: .zero, reuseIdentifier: demoAnnotationViewReuseID)
        annotationView.annotation = annotation as? DemoAnnotation
        annotationView.isSelected = selectedAnnotation?.identifier == annotation.identifier
        return annotationView
    }

    func tiledScrollView(_ scrollView: JCTiledScrollView, imageForRow row: Int, column: Int, scale: Int) -> UIImage? {
        let fileName = NSString(format: "%@_%dx_%d_%d.png", SkippingGirlImageName, scale, row, column) as String
        return UIImage(named: fileName)

    }

    // MARK: UIAlertView Delegate
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        guard let buttonTitle = alertView.buttonTitle(at: buttonIndex) else {
            return
        }
        switch buttonTitle {
        case ButtonTitleCancel:
            break
        case ButtonTitleRemoveAnnotation:
            if let selectedAnnotation = self.selectedAnnotation {
                scrollView.removeAnnotation(selectedAnnotation)
            }
        default:
            break
        }
    }
}

