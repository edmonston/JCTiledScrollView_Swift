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

class JCAnnotationView: UIView {
    var annotation: JCAnnotation?
    let reuseIdentifier: String
    
    var position: CGPoint = .zero {
        didSet {
            if !position.equalTo(oldValue) {
                recenter()
            }
        }
    }
    
    var centerOffset: CGPoint = .zero {
        didSet {
            if !centerOffset.equalTo(oldValue) {
                recenter()
            }
        }
    }

    init(frame: CGRect, reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: frame)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func recenter() {
        center = CGPoint(x: position.x + centerOffset.x, y: position.y + centerOffset.y)
    }
}

