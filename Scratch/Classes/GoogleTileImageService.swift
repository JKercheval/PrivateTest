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

class FieldBoundaryCorners {
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
    var northEast : CLLocationCoordinate2D
    var southWest : CLLocationCoordinate2D
    private var gmsBoundary : GMSCoordinateBounds

    init(withCoordinates northWest : CLLocationCoordinate2D, southEast : CLLocationCoordinate2D,
         northEast : CLLocationCoordinate2D, southWest : CLLocationCoordinate2D) {
        self.northWest = northWest
        self.southEast = southEast
        self.northEast = northEast
        self.southWest = southWest
        gmsBoundary = GMSCoordinateBounds(coordinate: northWest, coordinate: southEast)
    }
    
    func intersects(bounds : GMSCoordinateBounds) -> Bool {
        return gmsBoundary.intersects(bounds)
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

/// This class handles all the code necessary to use on drawing surface, and create the tiles when
/// needed.
class GoogleTileImageService {

    let fieldBoundary : FieldBoundaryCorners
    var widthRatio : CGFloat = 0
    var hieghtRatio : CGFloat = 0

    var mapView : MapViewProtocol!
    var currentPlottedRowZoomLevel : UInt = 0
    var imageCanvas : PlottingImageCanvasProtocol!
    var currentTileZoom : UInt = 20
    
    /// Initialization method
    /// - Parameters:
    ///   - boundaryRect: CGRect of the field
    ///   - boundQuad: BoundaryQuad object which contains the NW, NE, SW, and SE CLLocationCoordinate2D coordinates.
    ///   - mapView: User Mode GMSMapView - this is the GMSMapView that represents what the user is actually seing on
    ///     the screen
    ///   - zoom: Zoom level which will be used to create default drawing surface.
    init(with boundaryRect : CGRect, boundQuad : FieldBoundaryCorners, canvas : PlottingImageCanvasProtocol, mapView : MapViewProtocol,  zoom : UInt = 20) {

        fieldBoundary = boundQuad
        self.mapView = mapView
        imageCanvas = canvas
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
        
        let metersPerPixel = self.getMetersPerPixel(coord: tileLoc.northWest, zoom: 20)
        let convertedSouthWestCorner = CLLocationCoordinate2D(latitude: tileLoc.southEast.latitude, longitude: tileLoc.northWest.longitude)
        let convertedNorthEastCorner = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: tileLoc.southEast.longitude)
        
        let tileWidth = tileLoc.northWest.distance(from: convertedNorthEastCorner)
        let tileHeight = tileLoc.northWest.distance(from: convertedSouthWestCorner)
        
        let convertedTileWidth = tileWidth / metersPerPixel
        let convertedTileHeight = tileHeight / metersPerPixel
        
        // Distance from left edge of tile, to left edge of image
        let northWestImageCornerLon = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: fieldBoundary.northWest.longitude)
        let northWestImageCornerLat = CLLocationCoordinate2D(latitude: fieldBoundary.northWest.latitude, longitude: tileLoc.northWest.longitude)

        let xDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLon)
        let yDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLat)
        
        let convertedXDistanceFromCorner = xDistanceFromCorner / metersPerPixel
        let convertedYDistanceFromCorner = yDistanceFromCorner / metersPerPixel
        var xPt : CGFloat = CGFloat(convertedXDistanceFromCorner)
        var yPt : CGFloat = CGFloat(convertedYDistanceFromCorner)

        let imageCornerPt = tileCorners.northWestImageOriginScreenPt
        let tileCornerPt = tileCorners.northWestTileOriginScreenPt

        let tileNWCornerLocation = CLLocation(latitude: tileLoc.northWest.latitude, longitude: tileLoc.northWest.longitude)
        let imageNWCornerLocationLon = CLLocation(latitude: northWestImageCornerLon.latitude, longitude: northWestImageCornerLon.longitude)
        let xBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLon)

        let imageNWCornerLocationLat = CLLocation(latitude: northWestImageCornerLat.latitude, longitude: northWestImageCornerLat.longitude)
        let yBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLat)
        
        var imageWidth = self.imageCanvas.imageSize.width
        var imageHeight = self.imageCanvas.imageSize.height
        
        if imageCornerPt.x < tileCornerPt.x {
            
            if xBearing < 0.0 {
                imageWidth = min(CGFloat(convertedTileWidth), self.imageCanvas.imageSize.width - CGFloat(convertedXDistanceFromCorner))
            }
        }
        else {
            xPt = 0
            if self.imageCanvas.imageSize.width > CGFloat(convertedTileWidth - convertedXDistanceFromCorner) {
                imageWidth = CGFloat(convertedTileWidth - convertedXDistanceFromCorner)
            }
        }

        if imageCornerPt.y < tileCornerPt.y {
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), self.imageCanvas.imageSize.height - CGFloat(convertedYDistanceFromCorner))
            }
        }
        else {
            yPt = 0
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), self.imageCanvas.imageSize.height - CGFloat(convertedYDistanceFromCorner))
            }
            else {
                if self.imageCanvas.imageSize.height > CGFloat(convertedTileHeight - convertedYDistanceFromCorner) {
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

        let gsmTileBoundary = GMSCoordinateBounds(coordinate: tileLoc.northWest, coordinate: tileLoc.southEast)
        guard fieldBoundary.intersects(bounds: gsmTileBoundary) else {
            return kGMSTileLayerNoTile
        }

        var tileCorners : TileCornerPoints = TileCornerPoints(northWestTileOriginScreenPt: CGPoint.zero,
                                                              southEastTileOriginScreenPt: CGPoint.zero,
                                                              northWestImageOriginScreenPt: CGPoint.zero)
        
        var nwImagePt : CGPoint = CGPoint.zero
        var seImagePt : CGPoint = CGPoint.zero
        let imageQuad = createTileImageQuad(tileLoc: tileLoc, boundary: self.fieldBoundary)

        // Handle all required projection calls now at one time to avoid being on the main thread as much as possible.
        DispatchQueue.main.sync {
            nwImagePt = mapView.point(for: imageQuad.northWest)
            seImagePt = mapView.point(for: imageQuad.southEast)
            
            let northWestTileOriginScreenPt = mapView.point(for: tileLoc.northWest)
            let southEastTileOriginScreenPt = mapView.point(for: tileLoc.southEast)
            let northWestImageOriginScreenPt = mapView.point(for: self.fieldBoundary.northWest)

            tileCorners = TileCornerPoints(northWestTileOriginScreenPt: northWestTileOriginScreenPt, southEastTileOriginScreenPt: southEastTileOriginScreenPt, northWestImageOriginScreenPt: northWestImageOriginScreenPt)
        }
        
        let imagePt = getOffsetPoint(tileCorners: tileCorners)
        // Currently the getOffsetPoint calculates the current ratios and they are stored in a class variable
        // TODO: Change this behavior
        let drawSize = CGSize(width: (seImagePt.x - nwImagePt.x) * self.widthRatio, height: (seImagePt.y - nwImagePt.y) * self.hieghtRatio)

        let imageRect = getCroppedImageRectForTile(tileLoc: tileLoc, zoom: zoom, tileCorners: tileCorners)
        guard let cropped = imageCanvas.getSubImageFromCanvas(with: imageRect) else {
            debugPrint("\(self):\(#function) ERROR! No Image returned from crop !!!")
            return nil
        }
        guard let retValue = createTileImage(imageFrom: cropped, startPt: imagePt, drawSize: drawSize, size: CGSize(width: TileSize, height: TileSize)) else {
            debugPrint("\(self):\(#function) ERROR! No Image returned from createTileImage !!!")
            return nil
        }

        return retValue
    }
    
    private func createTileImageQuad(tileLoc : TileCoordinate, boundary : FieldBoundaryCorners) -> FieldBoundaryCorners {
        let northWestCorner : CLLocationCoordinate2D = createNorthWestQuadLocation(tileLoc: tileLoc, quad: boundary)
        let northEastCorner : CLLocationCoordinate2D = createNorthEastQuadLocation(tileLoc: tileLoc, quad: boundary)
        let southWestCorner : CLLocationCoordinate2D = createSouthWestQuadLocation(tileLoc: tileLoc, quad: boundary)
        let southEastCorner : CLLocationCoordinate2D = createSouthEastQuadLocation(tileLoc: tileLoc, quad: boundary)
        
        return FieldBoundaryCorners(withCoordinates: northWestCorner, southEast: southEastCorner, northEast: northEastCorner, southWest: southWestCorner)
    }

    private func getCoordRect(coordinateQuad : FieldBoundaryCorners,  forZoomLevel zoom : UInt) -> CGRect {
        let topLeft = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northWest, zoom: zoom)
        let topRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northEast, zoom: zoom)
        let bottomRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.southEast, zoom: zoom)
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }
    
    /// Creates the image that will be used to pass back to the tile.
    /// - Parameters:
    ///   - imageFrom: UIImage of the cropped portion of the main image
    ///   - startPt: CGPoint of where we will draw in the cropped image.
    ///   - drawSize: CGSize of the cropped image.
    ///   - size: CGSize of the tile image.
    /// - Returns: UIImage for the currrent tile
    private func createTileImage(imageFrom : UIImage, startPt : CGPoint, drawSize : CGSize, size: CGSize) -> UIImage? {
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

extension GoogleTileImageService {
    
    func getMetersPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp
    }

    func drawRow(with plottedRow : PlottedRowInfoProtocol, zoom : UInt) -> Bool {
        return imageCanvas.drawRow(with: plottedRow)
    }
}
