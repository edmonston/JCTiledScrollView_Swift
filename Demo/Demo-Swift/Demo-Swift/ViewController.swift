//
//  ViewController.swift
//  Demo-Swift
//
//  Created by Yichi on 13/12/2014.
//  Copyright (c) 2014 Yichi Zhang. All rights reserved.
//

import UIKit

enum JCDemoType {
	case PDF
	case Image
}

let annotationReuseIdentifier = "JCAnnotationReuseIdentifier"
let SkippingGirlImageName = "SkippingGirl"
let SkippingGirlImageSize = CGSizeMake(432, 648)

let ButtonTitleCancel = "Cancel"
let ButtonTitleRemoveAnnotation = "Remove this Annotation"

@objc class ViewController: UIViewController, JCTiledScrollViewDelegate, JCTileSource, UIAlertViewDelegate {

	var scrollView: JCTiledScrollView!
	var infoLabel: UILabel!
	var searchField: UITextField!
	var mode: JCDemoType!
	
	weak var selectedAnnotation:JCAnnotation?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.
		
		if(mode == JCDemoType.PDF){
			scrollView = JCTiledPDFScrollView(frame: self.view.bounds, URL: NSBundle.mainBundle().URLForResource("Map", withExtension: "pdf")! )
		}else{
			scrollView = JCTiledScrollView(frame: self.view.bounds, contentSize: SkippingGirlImageSize)
		}
		scrollView.tiledScrollViewDelegate = self
		scrollView.zoomScale = 1.0
		
		scrollView.dataSource = self
		scrollView.tiledScrollViewDelegate = self
				
		scrollView.tiledView.shouldAnnotateRect = true
		 
		// totals 4 sets of tiles across all devices, retina devices will miss out on the first 1x set
		scrollView.levelsOfZoom = 3
		scrollView.levelsOfDetail = 3
		scrollView.setTranslatesAutoresizingMaskIntoConstraints(false)
		view.addSubview(scrollView)
		
		infoLabel = UILabel(frame: CGRectZero)
		infoLabel.backgroundColor = UIColor.blackColor()
		infoLabel.textColor = UIColor.whiteColor()
		infoLabel.textAlignment = NSTextAlignment.Center
		infoLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
		view.addSubview(infoLabel)
		
		view.addConstraints([
			NSLayoutConstraint(item: scrollView, attribute: .Width, relatedBy: .Equal, toItem: view, attribute: .Width, multiplier: 1, constant: 0),
			NSLayoutConstraint(item: scrollView, attribute: .Height, relatedBy: .Equal, toItem: view, attribute: .Height, multiplier: 1, constant: 0),
			NSLayoutConstraint(item: scrollView, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1, constant: 0),
			NSLayoutConstraint(item: scrollView, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1, constant: 0),
			
			NSLayoutConstraint(item: infoLabel, attribute: .Top, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1, constant: 20),
			NSLayoutConstraint(item: infoLabel, attribute: .CenterX, relatedBy: .Equal, toItem: view, attribute: .CenterX, multiplier: 1, constant: 0),
			])
		
		addRandomAnnotations()
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	func addRandomAnnotations() {
		for index in 0...4 {
			var a:JCAnnotation = DemoAnnotation()
			a.contentPosition = CGPointMake(
				CGFloat(UInt(arc4random_uniform(UInt32(UInt(scrollView.tiledView.bounds.width))))),
				CGFloat(UInt(arc4random_uniform(UInt32(UInt(scrollView.tiledView.bounds.height)))))
			)
			scrollView.addAnnotation(a)
		}
	}
	
	// MARK: JCTiledScrollView Delegate
	func tiledScrollViewDidZoom(scrollView: JCTiledScrollView) {
		
		infoLabel.text = NSString(format: "zoomScale=%.2f", scrollView.zoomScale) as String
	}
	
	func tiledScrollView(scrollView: JCTiledScrollView, didReceiveSingleTap gestureRecognizer: UIGestureRecognizer) {
		
		var tapPoint:CGPoint = gestureRecognizer.locationInView(scrollView.tiledView)
		
		infoLabel.text = NSString(format: "(%.2f, %.2f), zoomScale=%.2f", tapPoint.x, tapPoint.y, scrollView.zoomScale) as String
	}
	
	func tiledScrollView(scrollView: JCTiledScrollView, didSelectAnnotationView view: JCAnnotationView) {
		
		if view.annotation != nil {
			
			let av = UIAlertView(title: "Annotation Selected", message: "You've selected an annotation. What would you like to do with it?", delegate: self, cancelButtonTitle: ButtonTitleCancel, otherButtonTitles: ButtonTitleRemoveAnnotation )
			av.show()
			selectedAnnotation = view.annotation
		}
	}
	
	func tiledScrollView(scrollView: JCTiledScrollView!, viewForAnnotation annotation: JCAnnotation!) -> JCAnnotationView! {
		
		var view:DemoAnnotationView? = scrollView.dequeueReusableAnnotationViewWithReuseIdentifier(annotationReuseIdentifier) as? DemoAnnotationView
		
		if ( (view) == nil )
		{
			view = DemoAnnotationView(frame:CGRectZero, annotation:annotation, reuseIdentifier:"Identifier")
			view!.imageView.image = UIImage(named: "marker-red.png")
			view!.sizeToFit()
		}
		
		return view
	}
	
	func tiledScrollView(scrollView: JCTiledScrollView, imageForRow row: Int, column: Int, scale: Int) -> UIImage! {
		
		let fileName = NSString(format: "%@_%dx_%d_%d.png", SkippingGirlImageName, scale, row, column) as! String
		return UIImage(named: fileName)
		
	}
	
	// MARK: UIAlertView Delegate
	func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
		
		switch alertView.buttonTitleAtIndex(buttonIndex){
		case ButtonTitleCancel:
			break
		case ButtonTitleRemoveAnnotation:
			scrollView.removeAnnotation(self.selectedAnnotation)
		default:
			break
		}
		
	}
}

