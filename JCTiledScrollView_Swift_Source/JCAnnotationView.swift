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

    required public init(frame: CGRect, reuseIdentifier: String) {
        self.reuseIdentifier = reuseIdentifier
        super.init(frame: frame)
        self.translatesAutoresizingMaskIntoConstraints = false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var centerConstraints: (NSLayoutConstraint, NSLayoutConstraint)?
    
    override open func willMove(toSuperview newSuperview: UIView?) {
        guard newSuperview != nil else {
            centerConstraints = nil
            return
        }
        recenter()
    }
    
    private func recenter() {
        guard let view = superview else { return }
        let x = position.x + centerOffset.x
        let y = position.y + centerOffset.y
        guard let (xConstraint, yConstraint) = centerConstraints else {
            let xConstraint = NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal,
                                                 toItem: view, attribute: .left, multiplier: 1.0, constant: x)
            let yConstraint = NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal,
                                                 toItem: view, attribute: .top, multiplier: 1.0, constant: y)
            xConstraint.isActive = true
            yConstraint.isActive = true
            centerConstraints = (xConstraint, yConstraint)
            return
        }
        xConstraint.constant = x
        yConstraint.constant = y
    }
}

