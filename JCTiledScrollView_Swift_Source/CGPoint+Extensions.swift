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

extension CGPoint {
    func isInside(_ rect: CGRect, insetBy margin: CGFloat) -> Bool {
        return rect.insetBy(dx: margin, dy: margin).contains(self)
    }
}

extension CGRect {
    func randomPointInside() -> CGPoint {
        let randomX = CGFloat(UInt(arc4random_uniform(UInt32(UInt(width)))))
        let randomY = CGFloat(UInt(arc4random_uniform(UInt32(UInt(height)))))
        return CGPoint(x: origin.x + randomX, y: origin.y + randomY)
    }
}
