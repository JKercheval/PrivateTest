//
//  PlotDrawingView.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/1/20.
//

import Foundation
import UIKit
import GoogleMaps

class LayerDrawingView : UIView {
    var viewLayer : CGLayer!
    var imageCanvas : PlottingImageCanvasProtocol!

    /// Convenience initializer that takes the frame and TileImageSourceServer; will set up the view to listen for updates
    /// to the plotting canvas
    /// - Parameters:
    ///   - frame: The frame rectangle for the view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This method uses the frame rectangle to set the center and bounds properties accordingly.
    ///   - imageServer: TileImageSourceServer which provides the image.
    convenience init(frame: CGRect, canvas: PlottingImageCanvasProtocol) {
        self.init(frame: frame)
        self.imageCanvas = canvas
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        debugPrint("\(self)\(#function)")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        debugPrint("\(self)\(#function)")
        
        self.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        self.borderColor = UIColor.black
        self.borderWidth = 1
        self.setAnchorPoint(anchorPoint: CGPoint.zero)
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
//        let updateRect = ctx.boundingBoxOfClipPath
        ctx.translateBy(x: 0, y: layer.bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)

//        debugPrint("\(#function) UpdateRect is \(updateRect)")
        guard let image = self.imageCanvas.currentCGImage else {
            return
        }
        ctx.draw(image, in: layer.bounds)
    }
    
    @objc func onDidUpdateRow(_ notification:Notification) {
//        debugPrint("\(self)\(#function)")
        // get the plotted row object, and get the mapview
        guard let plottedRow = notification.object as? PlottedRowInfoProtocol,
              let mapView = self.superview as? GMSMapView else {
            return
        }
        // Where is the point of this coordinate in the mapview
        let point = mapView.projection.point(for: plottedRow.plottingCoordinate)
        // And where is this point in our view.
        let localPoint = self.convert(point, from: mapView)
        
        // Get the width - based on machine width
        // TODO: Get machine Width
//        let width = Measurement(value: self.imageCanvas.machineWidth, unit: UnitLength.feet).converted(to: UnitLength.meters).value

        let xPoints = mapView.projection.points(forMeters: self.imageCanvas.machineWidth, at: plottedRow.plottingCoordinate)
        let translatedPt = CGPoint(x: max(0, localPoint.x - xPoints/2), y: max(0, localPoint.y - xPoints/2))
        let displayRect = CGRect(origin: translatedPt, size: CGSize(width: xPoints, height: xPoints + 1))
        self.layer.setNeedsDisplay(displayRect)
    }

}

/// This class is used to display the plotting image.
class PlotDrawingView: UIView {
    
    var imageView : UIImageView!
    var imageCanvas : PlottingImageCanvasProtocol!
    
    /// Convenience initializer that takes the frame and TileImageSourceServer; will set up the view to listen for updates
    /// to the plotting canvas
    /// - Parameters:
    ///   - frame: The frame rectangle for the view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This method uses the frame rectangle to set the center and bounds properties accordingly.
    ///   - imageServer: TileImageSourceServer which provides the image.
    convenience init(frame: CGRect, canvas: PlottingImageCanvasProtocol) {
        self.init(frame: frame)
        self.imageCanvas = canvas
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        debugPrint("\(self)\(#function)")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        debugPrint("\(self)\(#function)")

        imageView = UIImageView(frame: CGRect(origin: CGPoint.zero, size: frame.size))
        imageView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        imageView.contentMode = .scaleAspectFit
        self.addSubview(imageView)
        
        self.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        self.borderColor = UIColor.black
        self.borderWidth = 1
        self.setAnchorPoint(anchorPoint: CGPoint.zero)
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Notification observer handler for plotting notifications
    /// - Parameter notification: Notification object
    @objc func onDidUpdateRow(_ notification:Notification) {
//        debugPrint("\(self)\(#function)")
        let plottingImage = self.imageCanvas.currentImage
        DispatchQueue.main.async {
            self.imageView.image = plottingImage
            self.imageView.setNeedsDisplay()
        }
    }
}
