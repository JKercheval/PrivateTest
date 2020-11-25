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

struct TileCoordinate {
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
}

class TileImageSourceServer {
    let boundary : CGRect
    let boundaryQuad : BoundaryQuad
    var image : UIImage?
    let sourceZoom : UInt // default to zoom level 20
    var widthRatio : CGFloat = 0
    var hieghtRatio : CGFloat = 0
    var metersPerPx : Double = 1
    var rowCount : Int = 54
    var internalMapView : GMSMapView!
    var mapView : GMSMapView!
    
    
    init(with boundaryRect : CGRect, boundQuad : BoundaryQuad, mapView : GMSMapView,  zoom : UInt = 20) {
        boundary = boundaryRect
        boundaryQuad = boundQuad
        sourceZoom = zoom
        self.mapView = mapView
        self.metersPerPx = getMetersPerPixel(coord: boundQuad.northWest, zoom: 20)
        // Get the distance in meters.
        let widthDistance = boundaryQuad.northEast.distance(from: boundQuad.northWest)
        let heightDistance = boundaryQuad.northWest.distance(from: boundQuad.southWest)

        let imageWidth = widthDistance / self.metersPerPx
        let imageHeight = heightDistance / self.metersPerPx
        
//        let imageSize = CGSize(width: boundary.size.width * TileSize, height: boundary.size.height * TileSize)
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
//        debugPrint("\(self):\(#function) - Image grid is \(boundary.size)")
        image = self.createFirstImage(size: imageSize)
        let camera = GMSCameraPosition.camera(withLatitude: boundQuad.northWest.latitude, longitude: boundQuad.northWest.longitude, zoom: Float(20))
        
        self.internalMapView = GMSMapView.map(withFrame: UIScreen.screens.first!.bounds, camera: camera)
    }
    
    func createFirstImage(size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            // Create the image with a transparent background
            ctx.cgContext.setFillColor(UIColor.clear.cgColor)
            ctx.cgContext.setAlpha(0.2)
            let imageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
            ctx.cgContext.fill(imageRect)
            ctx.cgContext.addRect(imageRect)
            ctx.cgContext.setStrokeColor(UIColor.black.cgColor)
            ctx.cgContext.setLineWidth(25.0)
            ctx.cgContext.drawPath(using: .fillStroke)
        }
        return img
    }
    
    var imageCanvas : UIImage? {
        return image
    }
    
    func setCenterCoordinate(coord : CLLocationCoordinate2D) {
        let newPosition = GMSCameraPosition.camera(
            withLatitude: coord.latitude,
            longitude: coord.longitude,
            zoom: Float(sourceZoom)
        )
        self.internalMapView.camera = newPosition
    }
    
    func getOffsetPoint(with mapView : GMSMapView, tileLoc : TileCoordinate, from coord : CLLocationCoordinate2D) -> CGPoint {
        var drawPoint = CGPoint.zero
        let northWestTileOriginScreenPt = mapView.projection.point(for: tileLoc.northWest)
        let southEastTileOriginScreenPt = mapView.projection.point(for: tileLoc.southEast)
        
        let northWestImageOriginScreenPt = mapView.projection.point(for: self.boundaryQuad.northWest)
//        debugPrint("\(self):\(#function) Image pt is: \(northWestImageOriginScreenPt)")
        
        // translation
        let tileWidth = southEastTileOriginScreenPt.x - northWestTileOriginScreenPt.x
        let tileHeight = southEastTileOriginScreenPt.y - northWestTileOriginScreenPt.y
        
        // transformation
        widthRatio = TileSize / tileWidth
        hieghtRatio = TileSize / tileHeight

        let xOffset = max(0, (northWestImageOriginScreenPt.x - northWestTileOriginScreenPt.x) * widthRatio)
        let yOffset = max(0, (northWestImageOriginScreenPt.y - northWestTileOriginScreenPt.y) * hieghtRatio)
        
        drawPoint = CGPoint(x: xOffset, y: yOffset)
//        debugPrint("\(self):\(#function) Offset pt is: \(drawPoint), ratios are: \(widthRatio), \(hieghtRatio)")
        //        }
        return drawPoint
    }
    
    func degreesToRadians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
    func radiansToDegrees(radians: Double) -> Double { return radians * 180.0 / .pi }
    
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

    func getCroppedImageRectForTile(gridSize : CGSize, tileLoc : TileCoordinate, zoom : UInt, offset : CGPoint) -> CGRect {
        
        guard let currentImage = self.image else {
            return CGRect.zero
        }

        let convertedSouthWestCorner = CLLocationCoordinate2D(latitude: tileLoc.southEast.latitude, longitude: tileLoc.northWest.longitude)
        let convertedNorthEastCorner = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: tileLoc.southEast.longitude)
        
        let tileWidth = tileLoc.northWest.distance(from: convertedNorthEastCorner)
        let tileHeight = tileLoc.northWest.distance(from: convertedSouthWestCorner)
        
        let convertedTileWidth = tileWidth / self.metersPerPx
        let convertedTileHeight = tileHeight / self.metersPerPx
        
        // Distance from left edge of tile, to left edge of image
        let northWestImageCornerLon = CLLocationCoordinate2D(latitude: tileLoc.northWest.latitude, longitude: boundaryQuad.northWest.longitude)
        let northWestImageCornerLat = CLLocationCoordinate2D(latitude: boundaryQuad.northWest.latitude, longitude: tileLoc.northWest.longitude)

        let xDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLon)// - offset.x
        let yDistanceFromCorner = tileLoc.northWest.distance(from: northWestImageCornerLat)// - offset.y
        
        let convertedXDistanceFromCorner = xDistanceFromCorner / self.metersPerPx
        let convertedYDistanceFromCorner = yDistanceFromCorner / self.metersPerPx
        var xPt : CGFloat = CGFloat(convertedXDistanceFromCorner)
        var yPt : CGFloat = CGFloat(convertedYDistanceFromCorner)

        let imageCornerPt = self.mapView.projection.point(for: boundaryQuad.northWest)
        let tileCornerPt = self.mapView.projection.point(for: tileLoc.northWest)

        let tileNWCornerLocation = CLLocation(latitude: tileLoc.northWest.latitude, longitude: tileLoc.northWest.longitude)
        let imageNWCornerLocationLon = CLLocation(latitude: northWestImageCornerLon.latitude, longitude: northWestImageCornerLon.longitude)
        let xBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLon)

        let imageNWCornerLocationLat = CLLocation(latitude: northWestImageCornerLat.latitude, longitude: northWestImageCornerLat.longitude)
        let yBearing = getBearingBetweenTwoPoints(point1: tileNWCornerLocation, point2: imageNWCornerLocationLat)
        
        var imageWidth = currentImage.size.width
        var imageHeight = currentImage.size.height
        
        if imageCornerPt.x < tileCornerPt.x {
            
            if xBearing < 0.0 {
                imageWidth = min(CGFloat(convertedTileWidth), currentImage.size.width - CGFloat(convertedXDistanceFromCorner))
            }
        }
        else {
            xPt = 0
            if currentImage.size.width > CGFloat(convertedTileWidth - convertedXDistanceFromCorner) {
                imageWidth = CGFloat(convertedTileWidth - convertedXDistanceFromCorner)
            }
        }

        if imageCornerPt.y < tileCornerPt.y {
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), currentImage.size.height - CGFloat(convertedYDistanceFromCorner))
            }
        }
        else {
            yPt = 0
            if yBearing.rounded() == 0.0 {
                imageHeight = min(CGFloat(convertedTileHeight), currentImage.size.height - CGFloat(convertedYDistanceFromCorner))
            }
            else {
                if currentImage.size.height > CGFloat(convertedTileHeight - convertedYDistanceFromCorner) {
                    imageHeight = CGFloat(convertedTileHeight - convertedYDistanceFromCorner)
                }
            }
        }

        let convertedRect = CGRect(x: xPt, y: yPt, width: imageWidth, height: imageHeight)
        return convertedRect
    }

    func getImageForTile(tile : CGPoint, tileLoc : TileCoordinate, zoom : UInt) -> UIImage? {
        DispatchQueue.main.sync {
            guard let currentImage = self.image else {
                return nil
            }
            let boundaryForZoom : CGRect = getCoordRect(coordinateQuad: self.boundaryQuad, forZoomLevel: zoom)
            if boundaryForZoom.contains(tile) == false {
                return nil
            }

            let imageQuad = createImageQuad(tileLoc: tileLoc)
            
            let nwImagePt = mapView.projection.point(for: imageQuad.northWest)
            let seImagePt = mapView.projection.point(for: imageQuad.southEast)

            let imagePt = getOffsetPoint(with: self.mapView, tileLoc: tileLoc, from: self.boundaryQuad.northWest)
            let imageRect = getCroppedImageRectForTile(gridSize: boundaryForZoom.size, tileLoc: tileLoc, zoom: zoom, offset: imagePt)
            guard let cropped = currentImage.crop(rect: imageRect) else {
                return nil
            }

            let drawSize = CGSize(width: (seImagePt.x - nwImagePt.x) * self.widthRatio, height: (seImagePt.y - nwImagePt.y) * self.hieghtRatio)
            guard let retValue = createTileImage(imageFrom: cropped, startPt: imagePt, drawSize: drawSize, size: CGSize(width: TileSize, height: TileSize)) else {
                debugPrint("\(self):\(#function) ERROR! No Image returned from createTileImage !!!")
                return nil
            }
            return retValue
        }
    }
    
    func createNorthWestQuadLocation(tileLoc : TileCoordinate) -> CLLocationCoordinate2D{
        // max lat, max long
        let northWestCorner : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: min(tileLoc.northWest.latitude, self.boundaryQuad.northWest.latitude), longitude: max(tileLoc.northWest.longitude, self.boundaryQuad.northWest.longitude))
        return northWestCorner
    }
    
    func createNorthEastQuadLocation(tileLoc : TileCoordinate) -> CLLocationCoordinate2D {
        // max latitude, min long
        let northEastCorner : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: min(tileLoc.northWest.latitude, self.boundaryQuad.northEast.latitude), longitude: min(tileLoc.southEast.longitude, self.boundaryQuad.northEast.longitude))
        return northEastCorner
    }
    
    func createSouthEastQuadLocation(tileLoc : TileCoordinate) -> CLLocationCoordinate2D{
        //min lat and min long
        let southEastCorner : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: max(tileLoc.southEast.latitude, self.boundaryQuad.southEast.latitude), longitude: min(tileLoc.southEast.longitude, self.boundaryQuad.southEast.longitude))
        return southEastCorner
    }

    func createSouthWestQuadLocation(tileLoc : TileCoordinate) -> CLLocationCoordinate2D{
        // Min long, max lat
        let southWestCorner : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: max(tileLoc.southEast.latitude, self.boundaryQuad.southEast.latitude), longitude: max(tileLoc.northWest.longitude, self.boundaryQuad.southWest.longitude))
        return southWestCorner
    }

    func createImageQuad(tileLoc : TileCoordinate) -> BoundaryQuad {
        let northWestCorner : CLLocationCoordinate2D = createNorthWestQuadLocation(tileLoc: tileLoc)
        let northEastCorner : CLLocationCoordinate2D = createNorthEastQuadLocation(tileLoc: tileLoc)
        let southWestCorner : CLLocationCoordinate2D = createSouthWestQuadLocation(tileLoc: tileLoc)
        let southEastCorner : CLLocationCoordinate2D = createSouthEastQuadLocation(tileLoc: tileLoc)
        
        return BoundaryQuad(withCoordinates: northWestCorner, southEast: southEastCorner, northEast: northEastCorner, southWest: southWestCorner)
    }

    private func getCoordRect(coordinateQuad : BoundaryQuad,  forZoomLevel zoom : UInt) -> CGRect {
        let topLeft = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northWest, zoom: zoom)
        let topRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.northEast, zoom: zoom)
        let bottomRight = MBUtils.createInfoWindowContent(latLng: coordinateQuad.southEast, zoom: zoom)
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }

    func createTileImage(imageFrom : UIImage, startPt : CGPoint, drawSize : CGSize, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            ctx.cgContext.setFillColor(UIColor.red.cgColor)
            ctx.cgContext.setAlpha(0.1)
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

    func addTextToImage(text: String, inImage: UIImage, atPoint:CGPoint) -> UIImage? {
        
        // Setup the font specific variables
        let textColor = UIColor.black
        let textFont = UIFont(name: "Helvetica Bold", size: 30)!
        
        //Setups up the font attributes that will be later used to dictate how the text should be drawn
        let textFontAttributes = [
            NSAttributedString.Key.font: textFont,
            NSAttributedString.Key.foregroundColor: textColor,
        ]
        
        // Create bitmap based graphics context
        UIGraphicsBeginImageContextWithOptions(inImage.size, false, 0.0)
        
        
        //Put the image into a rectangle as large as the original image.
        inImage.draw(in: CGRect(x: 0, y: 0, width: inImage.size.width, height: inImage.size.height))
        
        // Our drawing bounds
        let drawingBounds = CGRect(x: 0.0, y: 0.0, width: inImage.size.width, height: inImage.size.height)
        
        let textSize = text.size(withAttributes: [NSAttributedString.Key.font:textFont])
        let textRect = CGRect(x: drawingBounds.size.width/2 - textSize.width/2, y: drawingBounds.size.height/2 - textSize.height/2,
                              width: textSize.width, height: textSize.height)
        
        text.draw(in: textRect, withAttributes: textFontAttributes)
        
        // Get the image from the graphics context
        let newImag = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImag
    }
    
}

extension TileImageSourceServer {
    
    func getDrawPoint(with mapView : GMSMapView, from coord : CLLocationCoordinate2D) -> CGPoint {
        let mapPoint = internalMapView.projection.point(for: coord)

        let northWestTileOriginScreenPt = internalMapView.projection.point(for: self.boundaryQuad.northWest)
        let southEastTileOriginScreenPt = internalMapView.projection.point(for: self.boundaryQuad.southEast)
        
        // translation
        let tileWidth = southEastTileOriginScreenPt.x - northWestTileOriginScreenPt.x
        let tileHeight = southEastTileOriginScreenPt.y - northWestTileOriginScreenPt.y
        
        let imageSize = CGSize(width: boundary.size.width * TileSize, height: boundary.size.height * TileSize)
        // transformation
        widthRatio = imageSize.width / tileWidth
        hieghtRatio = imageSize.height / tileHeight
        
        //        debugPrint("WidthRatio: \(widthRatio),  Rounded Width Ratio: \(widthRatio.rounded(.up))")
        let xOffset = (mapPoint.x - northWestTileOriginScreenPt.x) * widthRatio
        let yOffset = (mapPoint.y - northWestTileOriginScreenPt.y) * hieghtRatio
        
        let drawPoint = CGPoint(x: xOffset, y: yOffset)
        return drawPoint
    }
    
    func getMetersPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp
    }

    func getInchesPerPixel(coord : CLLocationCoordinate2D, zoom : UInt) -> Double {
        let mpp = (156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoom))).rounded(toPlaces: 4)
        return mpp * inchesPerMeter
    }

    func drawRow(at coord : CLLocationCoordinate2D) -> Bool {
        // Our image size is currently the size of the rectangle defined by the field coordinates
        // So, take the current draw coordinates and calculate the offset from our topleft point.
        let horDistance = coord.distance(from: CLLocationCoordinate2D(latitude: coord.latitude, longitude: self.boundaryQuad.northWest.longitude))
        let verDistance = coord.distance(from: CLLocationCoordinate2D(latitude: self.boundaryQuad.northWest.latitude, longitude: coord.longitude))
        let verOffset = verDistance / self.metersPerPx
        let horOffset = horDistance / self.metersPerPx

        let drawPoint = CGPoint(x: horOffset, y: verOffset)
//        let drawPoint = getDrawPoint(with: zoomedMapView, from: coord)
        guard let currentImage = self.image else {
            return false
        }
        self.metersPerPx = getMetersPerPixel(coord: coord, zoom: 20)
        guard let newImage = drawRectangleOnImage(image: currentImage, atPoint: drawPoint) else {
            debugPrint("\(self):\(#function) - FAILED TO DRAW NEW POINT")
            return false
        }
        self.image = newImage
        return true
    }
    
    
    func drawRectangleOnImage(image : UIImage, atPoint point : CGPoint) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in
            
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.1)
            
            image.draw(at: CGPoint.zero)
            let partsWidth = CGFloat((120.0 / 54.0) / self.metersPerPx) // / widthRatio.rounded(.up)).rounded(toPlaces: 4)
//            debugPrint("\(self):\(#function) partsWidth is \(partsWidth)")
            let startX : CGFloat = point.x
            for n in 0..<self.rowCount {
                var color = UIColor.black.cgColor
                if n % 2 == 0 {
                    color = UIColor.red.cgColor
                }
                ctx.cgContext.setFillColor(color)
                let rect = CGRect(x: startX + (partsWidth * CGFloat(n)), y: point.y, width: partsWidth, height: partsWidth)
                ctx.cgContext.fill(rect)
            }
        }
        return img
    }

}
