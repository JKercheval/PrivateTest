//
//  LayerDrawingView.swift
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
    var mapView : MapViewProtocol!
    let aspectRatio : CGFloat
    
    /// Convenience initializer that takes the frame and TileImageSourceServer; will set up the view to listen for updates
    /// to the plotting canvas
    /// - Parameters:
    ///   - frame: The frame rectangle for the view, measured in points. The origin of the frame is relative to the superview in which you plan to add it. This method uses the frame rectangle to set the center and bounds properties accordingly.
    ///   - imageServer: TileImageSourceServer which provides the image.
    convenience init(frame: CGRect, canvas: PlottingImageCanvasProtocol, mapView : MapViewProtocol) {
        self.init(frame: frame)
        self.imageCanvas = canvas
        self.mapView = mapView
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        debugPrint("\(self)\(#function)")
    }
    
    override init(frame: CGRect) {
        self.aspectRatio = frame.height / frame.width
        super.init(frame: frame)
        debugPrint("\(self)\(#function)")

        self.backgroundColor = UIColor.red.withAlphaComponent(0.07)
        self.borderColor = UIColor.black
        self.borderWidth = 1
        self.setAnchorPoint(anchorPoint: CGPoint.zero)
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    /// The main draw method that just blits the image from the ImageCanvas into the layer.
    /// - Parameters:
    ///   - layer: CALayer which the drawing will go into.
    ///   - ctx: CGContext to use
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        // account for the cgImage being flipped.
        ctx.translateBy(x: 0, y: layer.bounds.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        
        guard let image = self.imageCanvas.currentCGImage else {
            assert(self.imageCanvas.currentCGImage != nil, "Failed to get the CGImage from the image canvas")
            return
        }
        // because the clipping seemss to be set in setNeedsDisplay(CGRect), we go ahead and specify the entire
        // bounds and the OS does the right thing.
        ctx.draw(image, in: layer.bounds)
    }
    
    
    /// This is the Notification message method that is called when a didPlotRowNotification message is posted.
    /// - Parameter notification: Notification object that contains the PlottedRowInfoProtocol object.
    @objc func onDidUpdateRow(_ notification:Notification) {

        // get the plotted row object - if there is no plotted point then there is a problem
        // TODO: Currently we are just passing the PlottedRowInfoProtocol in the object for the
        // notification, but it should be put in the dictionary.
        guard let plottedRow = notification.userInfo?[userInfoPlottedCoordinateKey] as? PlottedRowInfoProtocol else {
            assert(notification.object != nil, "There was no object passed")
            return
        }

        // Where is the point of this coordinate in the mapview
        let point = self.mapView.point(for: plottedRow.plottingCoordinate)
        // And where is this point in our view.
        let localPoint = self.convert(point, from: self.superview)
        // How many points does this implement span? (machineWidth is in meters)
        let xPoints = mapView.points(forMeters: self.imageCanvas.machineWidth, at: plottedRow.plottingCoordinate)
        
        // adjust the x and y to account for the width of the row draw (we just use the same value for height because
        // it may be drawn vertically).
        let translatedPt = CGPoint(x: max(0, localPoint.x - xPoints/2), y: max(0, localPoint.y - xPoints/2))
        let displayRect = CGRect(origin: translatedPt, size: CGSize(width: xPoints, height: xPoints + 1))
        
        // Using set 'setNeedsDisplay(CGRect)' is way more performant - we still draw the whole image into the CALayer
        // in the draw(_ layer: CALayer, in ctx: CGContext) above, but iOS does the right thing and optimizes what is
        // drawn.
        self.layer.setNeedsDisplay(displayRect)
    }

}
