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

    private var zoomLevel : UInt = 20
    private var fieldBoundary :FieldBoundaryCorners!
    private var machineInfo : MachineInfoProtocol!
    private var canvasImageSize : CGSize = CGSize.zero
    private var metersPerPixel : Double = 0
    private var lastPlottedRow : PlottedRowInfoProtocol?
    private var lastRowBoundsDrawn : GMSCoordinateBounds?
    private var displayPlottingContexts : [DisplayType : CGContext] = [DisplayType : CGContext]()
    private var plottingManager : PlottingManagerProtocol!
    var colorComponents : [CGFloat] = [CGFloat]()
    var locations : [CGFloat] = [CGFloat]()
    
    init(boundary : FieldBoundaryCorners, plottingManager : PlottingManagerProtocol) {
        self.fieldBoundary = boundary
        self.plottingManager = plottingManager
        self.machineInfo = plottingManager.machineInformation
        self.metersPerPixel = getMetersPerPixel(coord: self.fieldBoundary.northWest, zoom: zoomLevel)
        
        // Get the distance in meters.
        let widthDistance = self.fieldBoundary.northEast.distance(from: self.fieldBoundary.northWest)
        let heightDistance = self.fieldBoundary.northWest.distance(from: self.fieldBoundary.southWest)
        
        let imageWidth = widthDistance / self.metersPerPixel
        let imageHeight = heightDistance / self.metersPerPixel
        
        self.canvasImageSize = CGSize(width: imageWidth, height: imageHeight)
        self.displayPlottingContexts[.singulation] = createBitmapContext(size: canvasImageSize)
        self.displayPlottingContexts[.downforce] = createBitmapContext(size: canvasImageSize)
        self.displayPlottingContexts[.rideQuality] = createBitmapContext(size: canvasImageSize)

        NotificationCenter.default.addObserver(self, selector: #selector(onPlotNewRowReceived(notification:)), name:.plotNewRow, object: nil)
    }
    
    var currentCGImage: CGImage? {
        guard let context = self.displayPlottingContexts[self.plottingManager.currentDisplayType],
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
    
    func image(forDisplayType type : DisplayType) -> CGImage? {
        // TODO: Get the image for the display type
        // for now, just return current image while implementing
        return currentCGImage
    }
    
    func reset() {
        for type in DisplayType.allCases {
            guard let bitmapContext = self.displayPlottingContexts[type] else {
                return
            }
            let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: self.imageSize)
            bitmapContext.clear(imageRect)
        }
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
        let currentDisplayType = plottingManager.currentDisplayType
    
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
        // TODO: We need to get the values that correspond to the data type that we want to display... DashboardType
        guard let value = plottedRow.rowInfo[currentDisplayType], let context = self.displayPlottingContexts[currentDisplayType] else {
            return false
        }
        let success = drawRow(withContext: context, points: startingPoints, rowValues: value, displayType: currentDisplayType, metersPerPixel: self.metersPerPixel, drawHeight: drawHeight, headings: plottedRowHeadings)
        guard success else {
            debugPrint("Failed to draw into image")
            return success
        }
        DispatchQueue.global().async {
            for display in DisplayType.allCases {
                guard let value = plottedRow.rowInfo[display], let context = self.displayPlottingContexts[display], display != currentDisplayType else {
                    continue
                }
                let _ = self.drawRow(withContext: context, points: startingPoints, rowValues: value, displayType: display, metersPerPixel: self.metersPerPixel, drawHeight: drawHeight, headings: plottedRowHeadings)
            }
        }

        self.lastPlottedRow = plottedRow
        postRowDrawCompleteNotification(drawCoordinate: plottedRow)
        return success
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
    func drawRow(withContext bitmapContext : CGContext, points: StartingPoints, rowValues : [Float], displayType : DisplayType, metersPerPixel : Double, drawHeight : Double, headings : PlottedRowHeadings) -> Bool {

        assert(rowValues.count == self.machineInfo.numberOfRows, "Invalid row value array!")
        bitmapContext.setStrokeColor(UIColor.clear.cgColor)
        bitmapContext.setLineWidth(0.0)

        let cellRowWidth = CGFloat((self.machineInfo.machineWidth / Double(self.machineInfo.numberOfRows)) / metersPerPixel)
        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
        
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
            let fillColor = UIColor.color(forValue: value, displayType: displayType)
            bitmapContext.setFillColor(fillColor)
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
