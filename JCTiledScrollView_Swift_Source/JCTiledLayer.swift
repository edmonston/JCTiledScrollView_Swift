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

class JCTiledLayer: CATiledLayer
{
    private let kDefaultFadeDuration: CFTimeInterval = 0.08

    private var fadeDuration: CFTimeInterval
    {
        return kDefaultFadeDuration
    }
}

