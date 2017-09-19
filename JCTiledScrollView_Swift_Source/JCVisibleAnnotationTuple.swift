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

class JCVisibleAnnotationTuple: NSObject
{
    let annotation: JCAnnotation
    let view: JCAnnotationView

    init(annotation: JCAnnotation, view: JCAnnotationView) {
        self.annotation = annotation
        self.view = view
        super.init()

    }
}

extension Set where Element == JCVisibleAnnotationTuple {
    func visibleAnnotationTuple(for annotation: JCAnnotation) -> JCVisibleAnnotationTuple? {
        return first(where: { $0.annotation === annotation })
    }

    func visibleAnnotationTuple(for view: JCAnnotationView) -> JCVisibleAnnotationTuple? {
        return first(where: { $0.view === view })
    }
}
