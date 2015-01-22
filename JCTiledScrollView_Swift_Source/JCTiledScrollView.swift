//
//  JCTiledScrollView.swift
//  campusmap-swift
//
//  Created by Yichi on 19/01/2015.
//  Copyright (c) 2015 Yichi Zhang. All rights reserved.
//

import Foundation

let kJCTiledScrollViewAnimationTime = NSTimeInterval(0.1)

extension JCTiledScrollView{
	
	func makeMuteAnnotationUpdatesTrueFor(time:NSTimeInterval){
		
		self.muteAnnotationUpdates = true
		
		let popTime = dispatch_time(
			DISPATCH_TIME_NOW, Int64(time * Double(NSEC_PER_SEC)) )
		dispatch_after(popTime, dispatch_get_main_queue(), {
			self.muteAnnotationUpdates = false
		})
	}
	
	func t_viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
		return self.tiledView
	}
	
	func t_scrollViewDidZoom(scrollView: UIScrollView) {
		self.tiledScrollViewDelegate.tiledScrollViewDidZoom?(self)
	}
	
	func t_scrollViewDidScroll(scrollView: UIScrollView) {
		self.correctScreenPositionOfAnnotations()
		
		self.tiledScrollViewDelegate.tiledScrollViewDidScroll?(self)
	}
	
	func t_singleTapReceived(gestureRecognizer:UITapGestureRecognizer) {
		
		if gestureRecognizer.isKindOfClass(ADAnnotationTapGestureRecognizer.self) {
			
			let annotationGestureRecognizer = gestureRecognizer as ADAnnotationTapGestureRecognizer
			
			previousSelectedAnnotationTuple = currentSelectedAnnotationTuple
			currentSelectedAnnotationTuple = annotationGestureRecognizer.tapAnnotation
			
			if nil == annotationGestureRecognizer.tapAnnotation {
				
				if previousSelectedAnnotationTuple != nil {
					self.tiledScrollViewDelegate.tiledScrollView?(self, didDeselectAnnotationView: previousSelectedAnnotationTuple.view!)
				} else if self.centerSingleTap {
					self.setContentCenter(gestureRecognizer.locationInView(self.tiledView), animated: true)
				}
				
				self.tiledScrollViewDelegate.tiledScrollView?(self, didReceiveSingleTap: gestureRecognizer)
			} else {
				if previousSelectedAnnotationTuple != nil {
					var oldSelectedAnnotationView = previousSelectedAnnotationTuple.view
					
					if oldSelectedAnnotationView == nil {
						oldSelectedAnnotationView = self.tiledScrollViewDelegate.tiledScrollView(self, viewForAnnotation: previousSelectedAnnotationTuple.annotation)
					}
					self.tiledScrollViewDelegate.tiledScrollView?(self, didDeselectAnnotationView: oldSelectedAnnotationView)
				}
				if currentSelectedAnnotationTuple != nil {
					var currentSelectedAnnotationView = annotationGestureRecognizer.tapAnnotation.view
					self.tiledScrollViewDelegate.tiledScrollView?(self, didSelectAnnotationView: currentSelectedAnnotationView)
				}
			} // if nil == annotationGestureRecognizer.tapAnnotation
		} //  if gestureRecognizer.isKindOfClass(ADAnnotationTapGestureRecognizer.self)
	} // end of singleTapReceived(gestureRecognizer:UITapGestureRecognizer)
	
	func t_doubleTapReceived(gestureRecognizer:UITapGestureRecognizer) {
		if self.zoomsInOnDoubleTap{
			
			let newZoom = self.scrollView.jc_zoomScaleByZoomingIn(1.0)
			
			self.makeMuteAnnotationUpdatesTrueFor(kJCTiledScrollViewAnimationTime)
			
			if self.zoomsToTouchLocation {
				let bounds = scrollView.bounds
				let pointInView = CGPointApplyAffineTransform(
					gestureRecognizer.locationInView(scrollView),
					CGAffineTransformMakeScale(1 / scrollView.zoomScale, 1 / scrollView.zoomScale)
				)
				let newSize = CGSizeApplyAffineTransform(
					bounds.size,
					CGAffineTransformMakeScale(1 / newZoom, 1 / newZoom)
				)
				
				scrollView.zoomToRect(CGRectMake(pointInView.x - (newSize.width / 2),
					pointInView.y - (newSize.height / 2), newSize.width, newSize.height), animated: true)
			} else {
				scrollView.setZoomScale(newZoom, animated: true)
			}
			// if self.zoomsToTouchLocation
			
		} // if self.zoomsInOnDoubleTap
		
		self.tiledScrollViewDelegate.tiledScrollView?(self, didReceiveDoubleTap: gestureRecognizer)
	} // end of doubleTapReceived(gestureRecognizer:UITapGestureRecognizer)
	
	func t_twoFingerTapReceived(gestureRecognizer:UITapGestureRecognizer) {
		if self.zoomsOutOnTwoFingerTap{
			
			let newZoom = self.scrollView.jc_zoomScaleByZoomingOut(1.0)
			
			self.makeMuteAnnotationUpdatesTrueFor(kJCTiledScrollViewAnimationTime)
			
			scrollView.setZoomScale(newZoom, animated: true)
		}
		
		self.tiledScrollViewDelegate.tiledScrollView?(self, didReceiveTwoFingerTap: gestureRecognizer)
	}
	
	func t_screenPositionForAnnotation(annotation: JCAnnotation) -> CGPoint{
		var position = CGPointZero
		position.x = (annotation.contentPosition.x * self.zoomScale) - scrollView.contentOffset.x
		position.y = (annotation.contentPosition.y * self.zoomScale) - scrollView.contentOffset.y
		return position
	}
}