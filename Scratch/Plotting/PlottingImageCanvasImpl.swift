//
//  PlottingImageCanvasImpl.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/2/20.
//

import Foundation
import UIKit
import CoreLocation

class PlottingImageCanvasImpl : PlottingImageCanvasProtocol {

    private var fieldBoundary :FieldBoundaryCorners!
    private var mapView : MapViewProtocol!
    private var machineInfo : MachineInfoProtocol!
    private var canvasZoom : UInt
    private var metersPerPixel : Double = 0
    private var lastPlottedRow : PlottedRowInfoProtocol?
    var plottingBitmapContext : CGContext?
    
    init(boundary : FieldBoundaryCorners, machineInfo : MachineInfoProtocol,  mapView : MapViewProtocol,  zoomLevel : UInt = 20) {
        self.fieldBoundary = boundary
        self.mapView = mapView
        self.canvasZoom = zoomLevel
        self.machineInfo = machineInfo
        self.metersPerPixel = getMetersPerPixel(coord: self.fieldBoundary.northWest, zoom: zoomLevel)
        
        // Get the distance in meters.
        let widthDistance = self.fieldBoundary.northEast.distance(from: self.fieldBoundary.northWest)
        let heightDistance = self.fieldBoundary.northWest.distance(from: self.fieldBoundary.southWest)
        
        let imageWidth = widthDistance / self.metersPerPixel
        let imageHeight = heightDistance / self.metersPerPixel
        
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        self.plottingBitmapContext = createBitmapContext(size: imageSize)
    }
    
    var currentImage: UIImage? {
        guard let context = self.plottingBitmapContext,
              let image = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: image)
    }
    
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool {
        // Our image size is currently the size of the rectangle defined by the field coordinates
        // So, take the current draw coordinates and calculate the offset from our topleft point.

        let coord = plottedRow.plottingCoordinate
        
        let mpp = getMetersPerPixel(coord: coord, zoom: 20)
        let horDistance = coord.distance(from: CLLocationCoordinate2D(latitude: coord.latitude, longitude: self.fieldBoundary.northWest.longitude))
        let verDistance = coord.distance(from: CLLocationCoordinate2D(latitude: self.fieldBoundary.northWest.latitude, longitude: coord.longitude))
        let verOffset = verDistance / mpp
        let horOffset = horDistance / mpp
        
        let drawPoint = CGPoint(x: horOffset, y: verOffset)
        guard let canvas = self.plottingBitmapContext else {
            return false
        }
        // This default value is taken directly from the knowledge of how often the GPS Generator is creating points - the 5 below
        // is from the fact that we are measuring distance in meters per second, and we are generating a new coordinate 5 times per
        // second.
        var drawHeight = (Measurement(value: 6, unit: UnitSpeed.milesPerHour).converted(to: .metersPerSecond).value / 5) / mpp
        if let lastRow = self.lastPlottedRow {
            // get the distance between the rows
            drawHeight = coord.distance(from: lastRow.plottingCoordinate) / mpp
        }
        //        debugPrint("\(#function) Coord is: \(coord), Draw Point is: \(drawPoint), Draw Height is: \(drawHeight), meters per pixel is: \(mpp)")
        let radianHeading = radians(degrees: plottedRow.heading)
        guard drawRowIntoContext(bitmapContext: canvas, atPoint: drawPoint, metersPerPixel: mpp, drawHeight: drawHeight, heading: radianHeading) else {
            debugPrint("Failed to draw into image")
            return false
        }
        self.lastPlottedRow = plottedRow
        postRowDrawCompleteNotification()
        return true
    }
    
    func getSubImageFromCanvas(with subImageRect: CGRect) -> UIImage? {
        guard let context = self.plottingBitmapContext else {
            return nil
        }
        guard let cgImage = context.makeImage() else {
            return nil
        }
        guard let cropped = cgImage.cropping(to: subImageRect) else {
            return nil
        }
        
        // Convert to UIImage
        return UIImage(cgImage: cropped)
    }

}

extension PlottingImageCanvasImpl {
    
    /// Post a notification that the row was plotted to the image...
    /// - Returns: Void
    func postRowDrawCompleteNotification() -> Void {
        DispatchQueue.main.async {
            let notification = Notification(name: .didPlotRowNotification, object: nil, userInfo: nil)
            NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle, coalesceMask: .onName, forModes: nil)
        }
    }
    
    /// Draws an actual row of seed information to the bitmap context.
    /// - Parameters:
    ///   - bitmapContext: CGContext to draw into
    ///   - point: CGPoint for the start location
    ///   - metersPerPixel: Meters per pixel
    ///   - drawHeight: Height of the row to draw
    ///   - heading: Heading of the tractor (implement)
    /// - Returns: True if the row was successfully drawn into the CGContext, false otherwise (currently only returns true - do we need this?)
    func drawRowIntoContext(bitmapContext : CGContext, atPoint point : CGPoint, metersPerPixel : Double, drawHeight : Double, heading : Double) -> Bool {
        
        bitmapContext.setStrokeColor(UIColor.black.cgColor)
        bitmapContext.setLineWidth(0.1)
        
        let partsWidth = CGFloat((self.machineInfo.machineWidth / Double(self.machineInfo.numberOfRows)) / metersPerPixel)
        let startX : CGFloat = point.x
        
        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
        bitmapContext.saveGState()
        
        // calculate the rectangle of the whole section we are creating (all row rects created below) so that we can correctly
        // rotate the plotted row.
        let rect = CGRect(x: startX, y: point.y, width: CGFloat(self.machineInfo.machineWidth / metersPerPixel), height: CGFloat(drawHeight))
        let path :CGMutablePath  = CGMutablePath();
        let midX : CGFloat = rect.midX;
        let midY : CGFloat = rect.midY
        let transfrom: CGAffineTransform =
            CGAffineTransform(translationX: -midX, y: -midY).concatenating(CGAffineTransform(rotationAngle: CGFloat(heading))).concatenating(
                CGAffineTransform(translationX: midX, y: midY))
        
        // go through each planter row and create the rect and fill the color value in depending on what we are displaying...
        for n in 0..<self.self.machineInfo.numberOfRows {
            var color = UIColor.green.cgColor
            if n % 2 == 0 {
                color = UIColor.red.cgColor
            }
            bitmapContext.setFillColor(color)
            
            let rect = CGRect(x: startX + (partsWidth * CGFloat(n)), y: point.y, width: partsWidth, height: CGFloat(drawHeight))
            // add the small row rect in...
            path.addRect(rect, transform: transfrom)
            
            // Add the path again.
            bitmapContext.addPath(path)
            // this will not only draw (fill) the path, but it also clears it.
            bitmapContext.fillPath()
        }
        // Restore previous CGState (pop).
        bitmapContext.restoreGState()
        
        return true
    }

    /// Takes a coordinate and calculates the how many meters per pixel for current zoom.
    /// - Parameters:
    ///   - coord: CLLocationCoordinate2D
    ///   - zoom: Zoom used for calcuation
    /// - Returns: returns the meters per pixel
    func getMetersPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp
    }

    func createBitmapContext (size : CGSize) -> CGContext? {
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * Int(size.width)
        let bitmapContext = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)
        bitmapContext?.translateBy(x: 0, y: size.height)
        bitmapContext?.scaleBy(x: 1.0, y: -1.0)
        let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        
        // light shade of red so we can see our tiles
        bitmapContext?.setFillColor(UIColor.clear.cgColor)
        bitmapContext?.fill(imageRect)
        
        // Stroke outline
        //        bitmapContext?.addRect(imageRect)
        //        bitmapContext?.setStrokeColor(UIColor.black.cgColor)
        //        bitmapContext?.setLineWidth(5.0)
        //        bitmapContext?.drawPath(using: .fillStroke)
        
        return bitmapContext
    }
}

class MachineInfoProtocolImpl : MachineInfoProtocol {
    private var internalMachineWidth : Double
    private var numRows : UInt
    
    init(with machineWidth : Double, rowCount : UInt) {
        self.internalMachineWidth = machineWidth
        self.numRows = rowCount
    }
    
    var machineWidth: Double {
        return self.internalMachineWidth
    }
    
    var numberOfRows: UInt {
        return self.numRows
    }
}
