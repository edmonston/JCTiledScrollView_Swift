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

open class JCAnnotation: NSObject {
    public var contentPosition: CGPoint
    public let identifier: String
    
    public init(identifier: String, contentPosition: CGPoint) {
        self.contentPosition = contentPosition
        self.identifier = identifier
    }
}

