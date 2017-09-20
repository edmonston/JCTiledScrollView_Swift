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

extension UIScrollView {

    func jc_zoomScaleByZoomingIn(_ numberOfLevels: CGFloat) -> CGFloat {
        let zoom = powf(2, Float(log2(zoomScale) + numberOfLevels))
        return CGFloat(min(zoom, Float(maximumZoomScale)))
    }

    func jc_zoomScaleByZoomingOut(_ numberOfLevels: CGFloat) -> CGFloat {
        let zoom = powf(2, Float(log2(zoomScale) - numberOfLevels))
        return CGFloat(max(zoom, Float(minimumZoomScale)))
    }

    func jc_setContentCenter(_ center: CGPoint, animated: Bool) {
        var newContentOffset = contentOffset

        if contentSize.width > bounds.size.width {
            newContentOffset.x = max(0.0, (center.x * zoomScale) - (bounds.size.width / 2.0))
            newContentOffset.x = min(newContentOffset.x, (contentSize.width - bounds.size.width))
        }
        if contentSize.height > self.bounds.size.height {
            newContentOffset.y = max(0.0, (center.y * zoomScale) - (bounds.size.height / 2.0))
            newContentOffset.y = min(newContentOffset.y, (contentSize.height - bounds.size.height))
        }
        setContentOffset(newContentOffset, animated: animated)
    }
}
