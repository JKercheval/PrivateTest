//
//  TileImageSourceServer.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/20/20.
//

import Foundation
import UIKit
import CoreLocation
import GoogleMaps
import PINCache

class BoundaryQuad {
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
    var northEast : CLLocationCoordinate2D
    var southWest : CLLocationCoordinate2D

    init(withCoordinates northWest : CLLocationCoordinate2D, southEast : CLLocationCoordinate2D,
         northEast : CLLocationCoordinate2D, southWest : CLLocationCoordinate2D) {
        self.northWest = northWest
        self.southEast = southEast
        self.northEast = northEast
        self.southWest = southWest
    }
}

struct TileCornerPoints {
    var northWestTileOriginScreenPt : CGPoint
    var southEastTileOriginScreenPt : CGPoint
    var northWestImageOriginScreenPt : CGPoint
}

struct TileCoordinate {
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
}

struct MachineInfo {
    var width : Double // meters
    var rows : Int // number of rows on implement
}

// TODO: Caching started
struct TileInfo {
    var isDirty : Bool = false
    var image : UIImage? = nil
}
typealias TileDictionary = [String : TileInfo]

class TileCacheInfo {
    var lastPlottedPoint : CLLocationCoordinate2D?
    var tileCache : TileDictionary = TileDictionary()
}
// END CACHING STARTED code

protocol MapViewProtocol {
    func point(for coord : CLLocationCoordinate2D) -> CGPoint
}

/// This class handles all the code necessary to use on drawing surface, and create the tiles when
/// needed.
class TileImageSourceServer {
    let boundary : CGRect
    let boundaryQuad : BoundaryQuad
    let sourceZoom : UInt // default to zoom level 20
    var widthRatio : CGFloat = 0
    var hieghtRatio : CGFloat = 0
    var metersPerPixel : Double = 1
    var rowCount : Int = 54
//    var internalMapView : GMSMapView!
//    var mapView : GMSMapView!
    var mapView : MapViewProtocol!
    var plottingBitmapContext : CGContext?
    var tileBitmapContext : CGContext?
    var imageSize : CGSize = CGSize.zero
    var machineInfo : MachineInfo!
    var currentPlottedRowZoomLevel : UInt = 0
    var lastPlottedRow : CLLocationCoordinate2D?
    var lastDrawPt : CGPoint = CGPoint.zero
    
    
    /// Initialization method
    /// - Parameters:
    ///   - boundaryRect: CGRect of the field
    ///   - boundQuad: BoundaryQuad object which contains the NW, NE, SW, and SE CLLocationCoordinate2D coordinates.
    ///   - mapView: User Mode GMSMapView - this is the GMSMapView that represents what the user is actually seing on
    ///     the screen
    ///   - zoom: Zoom level which will be used to create default drawing surface.
    init(with boundaryRect : CGRect, boundQuad : BoundaryQuad, mapView : MapViewProtocol,  zoom : UInt = 20) {
        boundary = boundaryRect
        boundaryQuad = boundQuad
        sourceZoom = zoom
        machineInfo = MachineInfo(width: 27.432, rows: 54)
        self.mapView = mapView
        self.metersPerPixel = getMetersPerPixel(coord: boundQuad.northWest, zoom: 20)
        // Get the distance in meters.
        let widthDistance = boundaryQuad.northEast.distance(from: boundQuad.northWest)
        let heightDistance = boundaryQuad.northWest.distance(from: boundQuad.southWest)

        let imageWidth = widthDistance / self.metersPerPixel
        let imageHeight = heightDistance / self.metersPerPixel
        
        imageSize = CGSize(width: imageWidth, height: imageHeight)
        self.plottingBitmapContext = createBitmapContext(size: imageSize)
//        let camera = GMSCameraPosition.camera(withLatitude: boundQuad.northWest.latitude, longitude: boundQuad.northWest.longitude, zoom: Float(20))
//        self.internalMapView = GMSMapView.map(withFrame: UIScreen.screens.first!.bounds, camera: camera)
    }
    
    
    /// Create the bitmap context that we use for the main offscreen canvas.
    /// - Parameter size: CGSize with Width and Height of context.
    /// - Returns: A CGContext initialized for use as a background drawing canvas.
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
    
//    func setCenterCoordinate(coord : CLLocationCoordinate2D) {
//        let newPosition = GMSCameraPosition.camera(
//            withLatitude: coord.latitude,
//            longitude: coord.longitude,
//            zoom: Float(sourceZoom)
//        )
//        self.internalMapView.camera = newPosition
//    }
    
    var currentImage : UIImage? {
        get {
            guard let context = self.plottingBitmapContext,
                  let image = context.makeImage() else {
                return nil
            }
            return UIImage(cgImage: image)
        }
    }
    
    /// This method will get the offset for the portion of the image that will be contained in the tile.
    /// - Parameters:
    ///   - tileLoc: TileCoordinate object that contains the Northwest and Southeast corners of the tile in CLLocationCoordinate@D
    /// - Returns: Offset point for the location of where the portion of the image is that we are going to draw into
    func getOffsetPoint(tileCorners: TileCornerPoints) -> CGPoint {
        var drawPoint = CGPoint.zero
        // translation
        let tileWidth = tileCorners.southEastTileOriginScreenPt.x - tileCorners.northWestTileOriginScreenPt.x
        let tileHeight = tileCorners.southEastTileOriginScreenPt.y - tileCorners.northWestTileOriginScreenPt.y
        
        // transformation
        self.widthRatio = TileSize / tileWidth
        self.hieghtRatio = TileSize / tileHeight

        let xOffset = max(0, (tileCorners.northWestImageOriginScreenPt.x - tileCorners.northWestTileOriginScreenPt.x) * self.widthRatio)
        let yOffset = max(0, (tileCorners.northWestImageOriginScreenPt.y - tileCorners.northWestTileOriginScreenPt.y) * self.hieghtRatio)
        
        drawPoint = CGPoint(x: xOffset, y: yOffset)
        return drawPoint
    }
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
    
    /// Gets the bearing (heading) between two coordinates.
    /// - Parameters:
    ///   - point1: CLLocation of the start location
    ///   - point2: CLLocation of the end location
    /// - Returns: Double that is the bearing in degrees between the two locations
    func getBearingBetweenTwoPoints(point1 : CLLocation, point2 : CLLocation) -> Double {
        
        let lat1 = degreesToRadians(degrees: point1.coordinate.latitude)
        let lon1 = degreesToRadians(degrees: point1.coordinate.longitude)
        
        let lat2 = degreesToRadians(degrees: point2.coordinate.latitude)
        let lon2 = degreesToRadians(degrees: point2.coordinate.longitude)
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        
        return radiansToDegrees(radians: radiansBearing)
    }

    
    /// Gets the rect that represents the the portion of the image that we will eventually display into the
    /// tile.
    /// - Parameters:
    ///   - tileLoc: The northwest and southeast coordinates of the tile.
    ///   - zoom: The zoom level
    ///   - tileCorners: Contains the Northwest, Southeast corners of the the tile image, and the northwest corner point
    ///   of the main image
    /// - Returns: The CGRect of the image for the tile - a subimage of the main image.
    func getCroppedImageRectForTile(tileLoc : TileCoordinate, zoom : UInt, tileCorners : TileCornerPoints) -> CGRect {
        
        let convertedSouthWestCorner = CLLocationCoordinate2D(latitude: tileLoc.southEast.latitude, longitude: tileLoc.northWest.longitude)
        let convertedNorthEastCorner = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: tileLoc.southEast.longitude)
        
        let tileWidth = tileLoc.northWest.distance(from: convertedNorthEastCorner)
        let tileHeight = tileLoc.northWest.distance(from: convertedSouthWestCorner)
        
        let convertedTileWidth = tileWidth / self.metersPerPixel
        let convertedTileHeight = tileHeight / self.metersPerPixel
        
        // Distance from left edge of tile, to left edge of image
        let northWestImageCornerLon = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: boundaryQuad.northWest.longitude)
        let northWestImageCornerLat = CLLocationCoordinate2D(latitude: boundaryQuad.northWest.latitude, longitude: tileLoc.northWest.longitude)

        let xDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLon)
        let yDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLat)
        
        let convertedXDistanceFromCorner = xDistanceFromCorner / self.metersPerPixel
        let convertedYDistanceFromCorner = yDistanceFromCorner / self.metersPerPixel
        var xPt : CGFloat = CGFloat(convertedXDistanceFromCorner)
        var yPt : CGFloat = CGFloat(convertedYDistanceFromCorner)

        let imageCornerPt = tileCorners.northWestImageOriginScreenPt
        let tileCornerPt = tileCorners.northWestTileOriginScreenPt

        let tileNWCornerLocation = CLLocation(latitude: tileLoc.northWest.latitude, longitude: tileLoc.northWest.longitude)
        let imageNWCornerLocationLon = CLLocation(latitude: northWestImageCornerLon.latitude, longitude: northWestImageCornerLon.longitude)
        let xBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLon)

        let imageNWCornerLocationLat = CLLocation(latitude: northWestImageCornerLat.latitude, longitude: northWestImageCornerLat.longitude)
        let yBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLat)
        
        var imageWidth = self.imageSize.width
        var imageHeight = self.imageSize.height
        
        if imageCornerPt.x < tileCornerPt.x {
            
            if xBearing < 0.0 {
                imageWidth = min(CGFloat(convertedTileWidth), self.imageSize.width - CGFloat(convertedXDistanceFromCorner))
            }
        }
        else {
            xPt = 0
            if self.imageSize.width > CGFloat(convertedTileWidth - convertedXDistanceFromCorner) {
                imageWidth = CGFloat(convertedTileWidth - convertedXDistanceFromCorner)
            }
        }

        if imageCornerPt.y < tileCornerPt.y {
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), self.imageSize.height - CGFloat(convertedYDistanceFromCorner))
            }
        }
        else {
            yPt = 0
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), self.imageSize.height - CGFloat(convertedYDistanceFromCorner))
            }
            else {
                if self.imageSize.height > CGFloat(convertedTileHeight - convertedYDistanceFromCorner) {
                    imageHeight = CGFloat(convertedTileHeight - convertedYDistanceFromCorner)
                }
            }
        }

        let convertedRect = CGRect(x: xPt, y: yPt, width: imageWidth, height: imageHeight)
        return convertedRect
    }

    
    /// Get the UIImage that represents the tile at the given location
    /// - Parameters:
    ///   - tile: The tile grid point
    ///   - tileLoc: The coordinates of the tile
    ///   - zoom: The zoom level for the request.
    /// - Returns: A UIImage that contains the actual tile image to be displayed.
    func getImageForTile(tile : CGPoint, tileLoc : TileCoordinate, zoom : UInt) -> UIImage? {
        var tileCorners : TileCornerPoints = TileCornerPoints(northWestTileOriginScreenPt: CGPoint.zero, southEastTileOriginScreenPt: CGPoint.zero, northWestImageOriginScreenPt: CGPoint.zero)

        var nwImagePt : CGPoint = CGPoint.zero
        var seImagePt : CGPoint = CGPoint.zero
        let boundaryForZoom : CGRect = getCoordRect(coordinateQuad: self.boundaryQuad, forZoomLevel: zoom)
        if boundaryForZoom.contains(tile) == false {
            return kGMSTileLayerNoTile
        }
        let imageQuad = createTileImageQuad(tileLoc: tileLoc, boundary: self.boundaryQuad)
//        let gmsBounds = GMSCoordinateBounds(coordinate: tileLoc.northWest, coordinate: tileLoc.southEast)
//        let tileKey = MBUtils.stringForCaching(withPoint: tile, zoomLevel: zoom)

        // Handle all required projection calls now at one time to avoid being on the main thread as much as possible.
        DispatchQueue.main.sync {
            nwImagePt = mapView.point(for: imageQuad.northWest)
            seImagePt = mapView.point(for: imageQuad.southEast)
            
            let northWestTileOriginScreenPt = mapView.point(for: tileLoc.northWest)
            let southEastTileOriginScreenPt = mapView.point(for: tileLoc.southEast)
            let northWestImageOriginScreenPt = mapView.point(for: self.boundaryQuad.northWest)

            tileCorners = TileCornerPoints(northWestTileOriginScreenPt: northWestTileOriginScreenPt, southEastTileOriginScreenPt: southEastTileOriginScreenPt, northWestImageOriginScreenPt: northWestImageOriginScreenPt)
        }
        
        let imagePt = getOffsetPoint(tileCorners: tileCorners)
        // Currently the getOffsetPoint calculates the current ratios and they are stored in a class variable
        // TODO: Change this behavior
        let drawSize = CGSize(width: (seImagePt.x - nwImagePt.x) * self.widthRatio, height: (seImagePt.y - nwImagePt.y) * self.hieghtRatio)

        let imageRect = getCroppedImageRectForTile(tileLoc: tileLoc, zoom: zoom, tileCorners: tileCorners)
        guard let cropped = getSubImageFromCanvas(bitmapContext: self.plottingBitmapContext, rect: imageRect) else {
            debugPrint("\(self):\(#function) ERROR! No Image returned from crop !!!")
            return nil
        }
        guard let retValue = createTileImage(imageFrom: cropped, startPt: imagePt, drawSize: drawSize, size: CGSize(width: TileSize, height: TileSize)) else {
            debugPrint("\(self):\(#function) ERROR! No Image returned from createTileImage !!!")
            return nil
        }
//        PINMemoryCache.shared.setObject(retValue, forKey: tileKey)
        return retValue
    }
    
    func createTileImageQuad(tileLoc : TileCoordinate, boundary : BoundaryQuad) -> BoundaryQuad {
        let northWestCorner : CLLocationCoordinate2D = createNorthWestQuadLocation(tileLoc: tileLoc, quad: boundary)
        let northEastCorner : CLLocationCoordinate2D = createNorthEastQuadLocation(tileLoc: tileLoc, quad: boundary)
        let southWestCorner : CLLocationCoordinate2D = createSouthWestQuadLocation(tileLoc: tileLoc, quad: boundary)
        let southEastCorner : CLLocationCoordinate2D = createSouthEastQuadLocation(tileLoc: tileLoc, quad: boundary)
        
        return BoundaryQuad(withCoordinates: northWestCorner, southEast: southEastCorner, northEast: northEastCorner, southWest: southWestCorner)
    }

    private func getCoordRect(coordinateQuad : BoundaryQuad,  forZoomLevel zoom : UInt) -> CGRect {
        let topLeft = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northWest, zoom: zoom)
        let topRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northEast, zoom: zoom)
        let bottomRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.southEast, zoom: zoom)
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }

    
    /// Gets the sub image that contains the relevant portion of the image for drawing into the tile.
    /// - Parameters:
    ///   - bitmapContext: CGContext of the canvas
    ///   - rect: CGRect that contains the coordinates to extract the image.
    /// - Returns: UIImage of the cropped image.
    func getSubImageFromCanvas(bitmapContext : CGContext?, rect : CGRect) -> UIImage? {
        guard let context = bitmapContext else {
            return nil
        }
        guard let cgImage = context.makeImage() else {
            return nil
        }
        guard let cropped = cgImage.cropping(to: rect) else {
            return nil
        }
        
        // Convert back to UIImage
        return UIImage(cgImage: cropped)
    }
    
    
    /// Creates the image that will be used to pass back to the tile.
    /// - Parameters:
    ///   - imageFrom: UIImage of the cropped portion of the main image
    ///   - startPt: CGPoint of where we will draw in the cropped image.
    ///   - drawSize: CGSize of the cropped image.
    ///   - size: CGSize of the tile image.
    /// - Returns: <#description#>
    func createTileImage(imageFrom : UIImage, startPt : CGPoint, drawSize : CGSize, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.red.cgColor)
            ctx.cgContext.setAlpha(0.01)
            let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)

            ctx.cgContext.fill(imageRect)

            imageFrom.draw(in: CGRect(origin: startPt, size: drawSize))
            ctx.cgContext.addRect(imageRect)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(10.0)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
        return img
    }

}

extension TileImageSourceServer {
    
    func getMetersPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp
    }

    func getInchesPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp * inchesPerMeter
    }

    func drawRow(with plottedRow : PlottedRow, zoom : UInt) -> Bool {
        // Our image size is currently the size of the rectangle defined by the field coordinates
        // So, take the current draw coordinates and calculate the offset from our topleft point.
        if self.currentPlottedRowZoomLevel != zoom {
            currentPlottedRowZoomLevel = zoom
        }
        let coord = plottedRow.coord
        
        let mpp = getMetersPerPixel(coord: coord, zoom: 20)
        let horDistance = coord.distance(from: CLLocationCoordinate2D(latitude: coord.latitude, longitude: self.boundaryQuad.northWest.longitude))
        let verDistance = coord.distance(from: CLLocationCoordinate2D(latitude: self.boundaryQuad.northWest.latitude, longitude: coord.longitude))
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
            drawHeight = coord.distance(from: lastRow) / mpp
        }
//        debugPrint("Draw Height is: \(drawHeight)")
        guard drawRowIntoContext(bitmapContext: canvas, atPoint: drawPoint, metersPerPixel: mpp, drawHeight: drawHeight, heading: radians(degrees: plottedRow.heading)) else {
            debugPrint("Failed to draw into image")
            return false
        }
        self.lastPlottedRow = coord
        self.lastDrawPt = drawPoint
        postRowDrawCompleteNotification()
        return true
    }
    
    func postRowDrawCompleteNotification() -> Void {
        DispatchQueue.main.async {
            let notification = Notification(name: .didPlotRowNotification, object: nil, userInfo: nil)
            NotificationQueue.default.enqueue(notification, postingStyle: .whenIdle, coalesceMask: .onName, forModes: nil)
        }
    }
    
    func imageFromContext(context : CGContext) -> UIImage? {
        guard let cgImage = context.makeImage() else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .downMirrored)
    }
    
    func drawRowIntoContext(bitmapContext : CGContext, atPoint point : CGPoint, metersPerPixel : Double, drawHeight : Double, heading : Double) -> Bool {

        bitmapContext.setStrokeColor(UIColor.black.cgColor)
        bitmapContext.setLineWidth(0.1)
        
        let partsWidth = CGFloat((self.machineInfo.width / Double(self.machineInfo.rows)) / metersPerPixel)
        let startX : CGFloat = point.x

        // We want to do each row independently, so we push our CGContext state, make rotation changes, then pop the state
        // when we are done.
        bitmapContext.saveGState()
        
        // calculate the rectangle of the whole section we are creating (all row rects created below) so that we can correctly
        // rotate the plotted row.
        let rect = CGRect(x: startX, y: point.y, width: CGFloat(self.machineInfo.width / metersPerPixel), height: CGFloat(drawHeight))
        let path :CGMutablePath  = CGMutablePath();
        let midX : CGFloat = rect.midX;
        let midY : CGFloat = rect.midY
        let transfrom: CGAffineTransform =
            CGAffineTransform(translationX: -midX, y: -midY).concatenating(CGAffineTransform(rotationAngle: CGFloat(heading))).concatenating(
                CGAffineTransform(translationX: midX, y: midY))

        // go through each planter row and create the rect and fill the color value in depending on what we are displaying...
        for n in 0..<self.rowCount {
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

}
