//
//  PlotDrawingView.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/1/20.
//

import Foundation
import UIKit


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
