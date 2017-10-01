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
import QuartzCore

@objc protocol JCTiledViewDelegate {
    func tiledView(_ tiledView: JCTiledView, imageForRow row: Int, column: Int, scale: Int) -> UIImage?
}

let kJCDefaultTileSize: CGFloat = 256.0

class JCTiledView: UIView {
    weak var delegate: JCTiledViewDelegate?

    var contentsScale: CGFloat = 1.0
    
    var scaleTransform: CGAffineTransform {
        return CGAffineTransform(scaleX: contentScaleFactor, y: contentScaleFactor)
    }
    
    var tiledLayer: CATiledLayer {
        return layer as! CATiledLayer
    }
    
    var tileSize: CGSize = CGSize(width: kJCDefaultTileSize, height: kJCDefaultTileSize) {
        didSet {
            tiledLayer.tileSize = tileSize.applying(scaleTransform)
        }
    }

    var shouldAnnotateRect = false

    var numberOfZoomLevels: Int {
        get {
            return tiledLayer.levelsOfDetailBias
        }
        set {
            tiledLayer.levelsOfDetailBias = newValue
        }
    }

    override class var layerClass: AnyClass {
        return CATiledLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let scaledTileSize = tileSize.applying(scaleTransform)
        tiledLayer.tileSize = scaledTileSize
        tiledLayer.levelsOfDetail = 1
        numberOfZoomLevels = 3
        contentsScale = tiledLayer.contentsScale
        backgroundColor = .green
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let scale = ctx.ctm.a / contentsScale
        let col = Int(rect.minX * scale / self.tileSize.width)
        let row = Int(rect.minY * scale / self.tileSize.height)
        let tileImage = delegate?.tiledView(self, imageForRow: row, column: col, scale: Int(scale))
        tileImage?.draw(in: rect)
        if (shouldAnnotateRect) {
            annotateRect(rect, inContext: ctx)
        }
    }

    // Handy for Debug
    func annotateRect(_ rect: CGRect, inContext ctx: CGContext) {
        let scale = ctx.ctm.a / contentsScale
        let lineWidth = 2.0 / scale
        let fontSize = 16.0 / scale

        UIColor.white.set()
        let attributes = [NSAttributedStringKey.font: UIFont.boldSystemFont(ofSize: fontSize)]
        let string = NSString.localizedStringWithFormat(" %0.0f", log2f(Float(scale)))
        let point = CGPoint(x: rect.minX, y: rect.minY)
        string.draw(at: point, withAttributes: attributes)

        UIColor.red.set()
        ctx.setLineWidth(lineWidth)
        ctx.stroke(rect)
    }
}

