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

open class JCAnnotationView: UIView {
    public var annotation: JCAnnotation?
    public let reuseIdentifier: String
    
    var position: CGPoint = .zero {
        didSet {
            guard position != oldValue else { return }
            recenter()
        }
    }
    
    public var centerOffset: CGPoint = .zero {
        didSet {
            guard centerOffset != oldValue else { return }
            recenter()
        }
    }

    public init(frame: CGRect, reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: frame)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func recenter() {
        center = CGPoint(x: position.x + centerOffset.x, y: position.y + centerOffset.y)
    }
}

