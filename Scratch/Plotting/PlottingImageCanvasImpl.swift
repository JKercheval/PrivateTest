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
extension PlottingImageCanvasImpl: NameDescribable {}
class PlottingImageCanvasImpl : PlottingImageCanvasProtocol {

    private var zoomLevel : UInt = 20
    private var fieldBoundary :FieldBoundaryCorners!
    private var machineInfo : MachineInfoProtocol!
    private var canvasImageSize : CGSize = CGSize.zero
    private var metersPerPixel : Double = 0
    private var lastPlottedRow : PlottedRowInfoProtocol?
//    private var lastRowBoundsDrawn : GMSCoordinateBounds?
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
        NotificationCenter.default.addObserver(self, selector: #selector(onPlotNewSessionDataReceived(notification:)), name:.plotSessionDataNotification, object: nil)
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
    
//    var lastRowBound: GMSCoordinateBounds? {
//        let bounds = self.lastRowBoundsDrawn
//        self.lastRowBoundsDrawn = nil
//        return bounds
//    }
    
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

    @objc func onPlotNewSessionDataReceived(notification : Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlotSessionDataKey] as? SessionData else {
            return
        }
        debugPrint("\(self.typeName):\(#function)")// : \(plottedRow)")
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

        let currentDisplayType = plottingManager.currentDisplayType
    
//        if let lastRow = self.lastPlottedRow {
//            // get the distance between the rows
//            if lastRowBoundsDrawn == nil {
//                lastRowBoundsDrawn = GMSCoordinateBounds(coordinate: plottedRow.plottingCoordinate, coordinate: lastRow.plottingCoordinate)
//            }
//            else {
//                lastRowBoundsDrawn?.includingCoordinate(plottedRow.plottingCoordinate)
//            }
//        }
        
        //        debugPrint("\(#function) Coord is: \(coord), Draw Point is: \(drawPoint), Draw Height is: \(drawHeight), meters per pixel is: \(mpp)")
        // TODO: We need to get the values that correspond to the data type that we want to display... DashboardType
        guard let context = self.displayPlottingContexts[currentDisplayType] else {
            return false
        }
        drawRow(withContext: context, plottedRow: plottedRow, displayType: currentDisplayType)
        DispatchQueue.global().async {
            for display in DisplayType.allCases {
                guard let context = self.displayPlottingContexts[display], display != currentDisplayType else {
                    continue
                }
                self.drawRow(withContext: context, plottedRow: plottedRow, displayType: display)
            }
        }

        self.lastPlottedRow = plottedRow
        postRowDrawCompleteNotification(drawCoordinate: plottedRow)
        return true
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
//    func drawRow(withContext bitmapContext : CGContext, points: StartingPoints, rowValues : [Float], displayType : DisplayType, metersPerPixel : Double, drawHeight : Double, headings : PlottedRowHeadings) -> Bool {
    
    
    /// Draws an actual row of seed information to the bitmap context.
    /// - Parameters:
    ///   - bitmapContext: CGContext to draw into
    ///   - plottedRow: PlottedRowInfoProtocol object that contains the required row information.
    ///   - displayType: DisplayType enum
    func drawRow(withContext bitmapContext : CGContext, plottedRow : PlottedRowInfoProtocol, displayType : DisplayType) {

        guard plottedRow.masterRowState == true else {
            debugPrint("Master row if off, nothing to draw")
            return
        }
        
        let coord = plottedRow.plottingCoordinate
        let currentStartingPt = getStartPt(fromCoord: coord)
        guard let nextPlottedRow = plottedRow.nextPlottedRow else {
            debugPrint("Failed to draw into image")
            return
        }

        let nextStartingPoint = getStartPt(fromCoord: nextPlottedRow.plottingCoordinate)
        let points = StartingPoints(currentStartingPoint: currentStartingPt, nextStartingPoint: nextStartingPoint)
        
        let headings = PlottedRowHeadings(currentHeading: plottedRow.heading, nextHeading: nextPlottedRow.heading)

        bitmapContext.setStrokeColor(UIColor.clear.cgColor)
        bitmapContext.setLineWidth(0.0)

        let cellRowWidth = CGFloat((self.machineInfo.machineWidth / Double(self.machineInfo.numberOfRows)) / metersPerPixel)
        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
        
        // This is the machine width adjusted to our canvas
        let pixelMachineWidth = CGFloat(self.machineInfo.machineWidth / metersPerPixel)
        
        // go through each planter row and create the rect and fill the color value in depending on what we are displaying...
//        for (index, value) in rowValues.enumerated() {
        for index in 0..<self.machineInfo.numberOfRows {
            let value = plottedRow.value(for: Int(index), displayType: displayType)
            if plottedRow.isWorkStateOnForRowIndex(index: Int(index)) == false {
                continue
            }
            
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

        return
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
