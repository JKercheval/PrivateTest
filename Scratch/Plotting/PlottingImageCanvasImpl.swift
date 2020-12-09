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

struct StartingPoints {
    var currentStartingPoint : CGPoint = CGPoint.zero
    var nextStartingPoint : CGPoint = CGPoint.zero
}

struct PlottedRowHeadings {
    var currentHeading : Double = 0
    var nextHeading : Double = 0
}

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
        NotificationCenter.default.addObserver(self, selector: #selector(onPlotNewRowReceived(notification:)), name:.plotNewRow, object: nil)
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
    
    func reset() {
        guard let bitmapContext = self.plottingBitmapContext else {
            return
        }
        let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: self.imageSize)
        bitmapContext.clear(imageRect)
    }
    
    @objc func onPlotNewRowReceived(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
            return
        }
        let _ = self.drawRow(with: plottedRow)
    }
    
    func getStartPt(fromCoord coord : CLLocationCoordinate2D) -> CGPoint {
        let horDistance = coord.distance(from: CLLocationCoordinate2D(latitude: coord.latitude, longitude: self.fieldBoundary.northWest.longitude))
        let verDistance = coord.distance(from: CLLocationCoordinate2D(latitude: self.fieldBoundary.northWest.latitude, longitude: coord.longitude))
        let verOffset = verDistance / self.metersPerPixel
        let horOffset = horDistance / self.metersPerPixel
        
        let startPt = CGPoint(x: horOffset, y: verOffset)
        return startPt
    }
    
    /// Draws a row defined by the PlottedRowInfoProtocal
    /// - Parameter plottedRow: PlottedRowInfoProtocol - contains the necessary information to draw a row
    /// - Returns: Bool - true if successful, false otherwise
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool {
        // Our image size is currently the size of the rectangle defined by the field coordinates
        // So, take the current draw coordinates and calculate the offset from our topleft point.

        let coord = plottedRow.plottingCoordinate
    
        let currentStartingPt = getStartPt(fromCoord: coord)
        guard let nextPlottedRow = plottedRow.nextPlottedRow else {
            return false
        }
        
        let nextStartingPoint = getStartPt(fromCoord: nextPlottedRow.plottingCoordinate)
        let startingPoints = StartingPoints(currentStartingPoint: currentStartingPt, nextStartingPoint: nextStartingPoint)
        
        let plottedRowHeadings = PlottedRowHeadings(currentHeading: plottedRow.heading, nextHeading: nextPlottedRow.heading)
        
        // This default value is taken directly from the knowledge of how often the GPS Generator is creating points - the 5 below
        // is from the fact that we are measuring distance in meters per second, and we are generating a new coordinate 5 times per
        // second.
        var drawHeight = (Measurement(value: 6, unit: UnitSpeed.milesPerHour).converted(to: .metersPerSecond).value / 5) / self.metersPerPixel
        if let lastRow = self.lastPlottedRow {
            // get the distance between the rows
            drawHeight = coord.distance(from: nextPlottedRow.plottingCoordinate) / self.metersPerPixel
            if lastRowBoundsDrawn == nil {
                lastRowBoundsDrawn = GMSCoordinateBounds(coordinate: coord, coordinate: lastRow.plottingCoordinate)
            }
            else {
                lastRowBoundsDrawn?.includingCoordinate(coord)
            }
        }
        
        //        debugPrint("\(#function) Coord is: \(coord), Draw Point is: \(drawPoint), Draw Height is: \(drawHeight), meters per pixel is: \(mpp)")
        guard drawRowIntoContext(withPoints: startingPoints, rowValues: plottedRow.rowInfo, metersPerPixel: self.metersPerPixel, drawHeight: drawHeight, headings: plottedRowHeadings) else {
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
            let notification = Notification(name: .didPlotRowNotification, object: self, userInfo: [userInfoPlottedCoordinateKey : drawCoordinate])
            NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle, coalesceMask: .onName, forModes: nil)
        }
    }
    
    func rotateRect(_ rect: CGRect) -> CGRect {
        let x = rect.midX
        let y = rect.midY
        let transform = CGAffineTransform(translationX: x, y: y)
            .rotated(by: .pi / 2)
            .translatedBy(x: -x, y: -y)
        return rect.applying(transform)
    }
    
    /// Draws an actual row of seed information to the bitmap context.
    /// - Parameters:
    ///   - bitmapContext: CGContext to draw into
    ///   - point: CGPoint for the start location
    ///   - metersPerPixel: Meters per pixel
    ///   - drawHeight: Height of the row to draw
    ///   - heading: Heading of the tractor (implement)
    /// - Returns: True if the row was successfully drawn into the CGContext, false otherwise (currently only returns true - do we need this?)
    func drawRowIntoContext(withPoints points: StartingPoints, rowValues : [CGFloat],  metersPerPixel : Double, drawHeight : Double, headings : PlottedRowHeadings) -> Bool {
        guard let bitmapContext = self.plottingBitmapContext else {
            return false
        }
        
        assert(rowValues.count == self.machineInfo.numberOfRows, "Invalid row value array!")
        bitmapContext.setStrokeColor(UIColor.black.cgColor)
        bitmapContext.setLineWidth(0.1)

        let cellRowWidth = CGFloat((self.machineInfo.machineWidth / Double(self.machineInfo.numberOfRows)) / metersPerPixel)
        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
//        bitmapContext.saveGState()
        
        // This is the machine width adjusted to our canvas
        let pixelMachineWidth = CGFloat(self.machineInfo.machineWidth / metersPerPixel)
        
        // calculate the rectangle of the whole section we are creating (all row rects created below) so that we can correctly
        // rotate the plotted row.
//        let rect = CGRect(x: startX, y: points.currentStartingPoint.y, width: pixelMachineWidth, height: rowHeight)
//        let transfrom: CGAffineTransform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
//            .rotated(by: CGFloat(radians(degrees: headings.currentHeading)))
//                    .translatedBy(x: -rect.midX, y: -rect.midY)

        // go through each planter row and create the rect and fill the color value in depending on what we are displaying...
        for (index, value) in rowValues.enumerated() {
            
            let cellRowPath = CGMutablePath();
            var color = UIColor.green.cgColor
            if value < 0.19 {
                color = UIColor.yellow.cgColor
            }
            else if value > 0.21 {
                color = UIColor.red.cgColor
            }
            bitmapContext.setFillColor(color)
            bitmapContext.beginPath()
            let topLeftOrig : CGPoint = CGPoint(x: points.nextStartingPoint.x - (pixelMachineWidth / 2.0) + (CGFloat(index) * cellRowWidth), y: points.nextStartingPoint.y)
            let  topLeftRotated = rotatePointAroundPivot(point: topLeftOrig, pivot: points.nextStartingPoint, degrees: headings.nextHeading)
            
            let topRightOrig : CGPoint = CGPoint(x: points.nextStartingPoint.x - (pixelMachineWidth / 2.0) + (CGFloat(index + 1) * cellRowWidth), y: points.nextStartingPoint.y)
            let topRightRotated = rotatePointAroundPivot(point: topRightOrig, pivot: points.nextStartingPoint, degrees: headings.nextHeading)
            
            let bottomLeftOrig = CGPoint(x: points.currentStartingPoint.x - (pixelMachineWidth / 2.0) + (CGFloat(index) * cellRowWidth), y: points.currentStartingPoint.y)
            let bottomLeftRotated = rotatePointAroundPivot(point: bottomLeftOrig, pivot: points.currentStartingPoint, degrees: headings.currentHeading)

            let bottomRightOrig = CGPoint(x: points.currentStartingPoint.x - (pixelMachineWidth / 2.0) + (CGFloat(index + 1) * cellRowWidth), y: points.currentStartingPoint.y)
            let bottomRightRotated = rotatePointAroundPivot(point: bottomRightOrig, pivot: points.currentStartingPoint, degrees: headings.currentHeading)

            cellRowPath.move(to: topLeftRotated)
            cellRowPath.addLine(to: topRightRotated)
            cellRowPath.addLine(to: bottomRightRotated)
            cellRowPath.addLine(to: bottomLeftRotated)

            // Add the path again.
            bitmapContext.addPath(cellRowPath)
            bitmapContext.closePath()

            // this will not only draw (fill) the path, but it also clears it.
            bitmapContext.fillPath()
        }
        // Restore previous CGState (pop).
//        bitmapContext.restoreGState()
        
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
