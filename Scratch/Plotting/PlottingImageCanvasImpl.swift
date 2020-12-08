//
//  PlottingImageCanvasImpl.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/2/20.
//

import Foundation
import UIKit
import CoreLocation
import GoogleMapsUtils

class PlottingImageCanvasImpl : PlottingImageCanvasProtocol {

    private var fieldBoundary :FieldBoundaryCorners!
    private var machineInfo : MachineInfoProtocol!
    private var canvasZoom : UInt
    private var canvasImageSize : CGSize = CGSize.zero
    private var metersPerPixel : Double = 0
    private var lastPlottedRow : PlottedRowInfoProtocol?
    private var lastRowBoundsDrawn : GMSCoordinateBounds?

    var plottingBitmapContext : CGContext?
    var colorComponents : [CGFloat] = [CGFloat]()
    var locations : [CGFloat] = [CGFloat]()
    
    init(boundary : FieldBoundaryCorners, machineInfo : MachineInfoProtocol,  zoomLevel : UInt = 20) {
        self.fieldBoundary = boundary
        self.canvasZoom = zoomLevel
        self.machineInfo = machineInfo
        self.metersPerPixel = getMetersPerPixel(coord: self.fieldBoundary.northWest, zoom: zoomLevel)
        
        // Get the distance in meters.
        let widthDistance = self.fieldBoundary.northEast.distance(from: self.fieldBoundary.northWest)
        let heightDistance = self.fieldBoundary.northWest.distance(from: self.fieldBoundary.southWest)
        
        let imageWidth = widthDistance / self.metersPerPixel
        let imageHeight = heightDistance / self.metersPerPixel
        
        self.canvasImageSize = CGSize(width: imageWidth, height: imageHeight)
        self.plottingBitmapContext = createBitmapContext(size: canvasImageSize)
        createGradientInfo()
    }
    
    var currentImage: UIImage? {
        guard let context = self.plottingBitmapContext,
              let image = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: image)
    }
    
    var currentCGImage: CGImage? {
        guard let context = self.plottingBitmapContext,
              let image = context.makeImage() else {
            return nil
        }
        return image
    }
    
    var machineWidth: Double {
        return self.machineInfo.machineWidth
    }
    
    var imageSize: CGSize {
        return self.canvasImageSize
    }
    
    var lastRowBound: GMSCoordinateBounds? {
        let bounds = self.lastRowBoundsDrawn
        self.lastRowBoundsDrawn = nil
        return bounds
    }
    
    /// Draws a row defined by the PlottedRowInfoProtocal
    /// - Parameter plottedRow: PlottedRowInfoProtocol - contains the necessary information to draw a row
    /// - Returns: Bool - true if successful, false otherwise
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool {
        // Our image size is currently the size of the rectangle defined by the field coordinates
        // So, take the current draw coordinates and calculate the offset from our topleft point.

        let coord = plottedRow.plottingCoordinate
    
        let horDistance = coord.distance(from: CLLocationCoordinate2D(latitude: coord.latitude, longitude: self.fieldBoundary.northWest.longitude))
        let verDistance = coord.distance(from: CLLocationCoordinate2D(latitude: self.fieldBoundary.northWest.latitude, longitude: coord.longitude))
        let verOffset = verDistance / self.metersPerPixel
        let horOffset = horDistance / self.metersPerPixel
        
        let drawPoint = CGPoint(x: horOffset, y: verOffset)
        guard let canvas = self.plottingBitmapContext else {
            return false
        }
        // This default value is taken directly from the knowledge of how often the GPS Generator is creating points - the 5 below
        // is from the fact that we are measuring distance in meters per second, and we are generating a new coordinate 5 times per
        // second.
        var drawHeight = (Measurement(value: 6, unit: UnitSpeed.milesPerHour).converted(to: .metersPerSecond).value / 5) / self.metersPerPixel
        if let lastRow = self.lastPlottedRow {
            // get the distance between the rows
            drawHeight = coord.distance(from: lastRow.plottingCoordinate) / self.metersPerPixel
            if lastRowBoundsDrawn == nil {
                lastRowBoundsDrawn = GMSCoordinateBounds(coordinate: coord, coordinate: lastRow.plottingCoordinate)
            }
            else {
                lastRowBoundsDrawn?.includingCoordinate(coord)
            }
        }
        
        //        debugPrint("\(#function) Coord is: \(coord), Draw Point is: \(drawPoint), Draw Height is: \(drawHeight), meters per pixel is: \(mpp)")
        let radianHeading = radians(degrees: plottedRow.heading)
        guard drawRowIntoContext(bitmapContext: canvas, atPoint: drawPoint, rowValues: plottedRow.rowInfo, metersPerPixel: self.metersPerPixel, drawHeight: drawHeight, heading: radianHeading) else {
            debugPrint("Failed to draw into image")
            return false
        }
        self.lastPlottedRow = plottedRow
        postRowDrawCompleteNotification(drawCoordinate: plottedRow)
        return true
    }
    
    
    /// Gets the subimage which is defined by the CGRect defined by the subImageRect
    /// - Parameter subImageRect: CGRect of the image
    /// - Returns: UIImage of the sub-image requested
    func getSubImageFromCanvas(with subImageRect: CGRect) -> UIImage? {
        guard subImageRect.isEmpty == false else {
            debugPrint("\(#function) - No CGRect defined, sub-image is invalid")
            return nil
        }
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
    func postRowDrawCompleteNotification(drawCoordinate : PlottedRowInfoProtocol) -> Void {
        DispatchQueue.main.async {
            let notification = Notification(name: .didPlotRowNotification, object: drawCoordinate, userInfo: nil)
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
    func drawRowIntoContext(bitmapContext : CGContext, atPoint point : CGPoint, rowValues : [CGFloat],  metersPerPixel : Double, drawHeight : Double, heading : Double) -> Bool {
        
        assert(rowValues.count == self.machineInfo.numberOfRows, "Invalid row value array!")
        bitmapContext.setStrokeColor(UIColor.black.cgColor)
        bitmapContext.setLineWidth(0.1)

        let partsWidth = CGFloat((self.machineInfo.machineWidth / Double(self.machineInfo.numberOfRows)) / metersPerPixel)
        
        // Starting point is the center of the implement, so we need to offset that soo that the starting point
        // is actually to the left of that by half of the machine width.
        let startX : CGFloat = point.x - ((partsWidth * CGFloat(machineInfo.numberOfRows)) / 2.0)
        
        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
        bitmapContext.saveGState()
        
        // calculate the rectangle of the whole section we are creating (all row rects created below) so that we can correctly
        // rotate the plotted row.
        let rect = CGRect(x: startX, y: point.y, width: CGFloat(self.machineInfo.machineWidth / metersPerPixel), height: CGFloat(drawHeight))
        let midX : CGFloat = rect.midX;
        let midY : CGFloat = rect.midY
        let transfrom: CGAffineTransform =
            CGAffineTransform(translationX: -midX, y: -midY).concatenating(CGAffineTransform(rotationAngle: CGFloat(heading))).concatenating(
                CGAffineTransform(translationX: midX, y: midY))
        
        // go through each planter row and create the rect and fill the color value in depending on what we are displaying...
        for (index, value) in rowValues.enumerated() {
            let path = CGMutablePath();
            var color = UIColor.green.cgColor
            if value < 0.19 {
                color = UIColor.yellow.cgColor
            }
            else if value > 0.21 {
                color = UIColor.red.cgColor
            }
            bitmapContext.setFillColor(color)
            bitmapContext.beginPath()
            let rect = CGRect(x: startX + (partsWidth * CGFloat(index)), y: point.y, width: partsWidth, height: CGFloat(drawHeight))
            // add the small row rect in...
            path.addRect(rect, transform: transfrom)
            
            // Add the path again.
            bitmapContext.addPath(path)
            bitmapContext.closePath()
            // An attempt at using a gradient... doesn't work on an angle.
//            let startPoint = CGPoint(x: rect.midX, y: rect.minY)
//            let endPoint = CGPoint(x: rect.midX, y: rect.maxY)
//            bitmapContext.saveGState()
//            bitmapContext.clip()
//            let normalizedNumber : CGFloat = value.normalize(min: 0.15, max: 0.25, from: 0, to: 0.8)
//            let locations : [CGFloat] = [max(0, normalizedNumber - 0.2), normalizedNumber, min(normalizedNumber + 0.2, 1)]
//
//            if let colorSpace = bitmapContext.colorSpace,
//               let gradient = CGGradient(colorSpace: colorSpace, colorComponents: colorComponents, locations: locations, count: 3) {
//                bitmapContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: CGGradientDrawingOptions(rawValue: UInt32(0)))
//            }
//
//            bitmapContext.restoreGState()
            // this will not only draw (fill) the path, but it also clears it.
            bitmapContext.fillPath()
        }
        // Restore previous CGState (pop).
        bitmapContext.restoreGState()
        
        return true
    }
    
    // rotates a point with a top left origin  around point pivot with 'degrees' in a clockwise fashion
    func rotatePointAroundPivot(point : CGPoint, pivot : CGPoint, degrees : Double) -> CGPoint {
        
        var destPoint : CGPoint = CGPoint.zero
        
        // subtract pivot
        let dx : Double = Double(point.x - pivot.x)
        let dy : Double = Double(point.y - pivot.y)
        
        let angle : Double = radians(degrees: degrees)
        
        let s : Double = sin(angle);
        let c : Double = cos(angle);
        
        // rotate around origin
        destPoint.x = CGFloat(dx * c - dy * s) + pivot.x;
        destPoint.y = CGFloat(dx * s + dy * c) + pivot.y;
        
        return destPoint;
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
    
    func createGradientInfo() {

        let startColor = UIColor.green
        guard let startColorComponents = startColor.cgColor.components else { return }

        let secondColor = UIColor.yellow
        guard let secondColorComponents = secondColor.cgColor.components else { return }

        let endColor = UIColor.red
        guard let endColorComponents = endColor.cgColor.components else { return }

        self.colorComponents = [startColorComponents[0], startColorComponents[1], startColorComponents[2], startColorComponents[3],
                                secondColorComponents[0], secondColorComponents[1], secondColorComponents[2], secondColorComponents[3],
                                endColorComponents[0], endColorComponents[1], endColorComponents[2], endColorComponents[3]]
    }
    
}
extension CGFloat {
    
    func normalize(min: CGFloat, max: CGFloat, from a: CGFloat = 0, to b: CGFloat = 1) -> CGFloat {
        return (b - a) * ((self - min) / (max - min)) + a
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
