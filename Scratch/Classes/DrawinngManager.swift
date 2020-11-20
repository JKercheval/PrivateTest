//
//  DrawinngManager.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/20/20.
//

import Foundation
import UIKit
import CoreLocation
import UIScreenExtension
import GoogleMaps
import PINCache

let inchesPerMeter: Double = 39.37007874

// DONT DELETE FOR NOW
//        let ppi = (UIScreen.pixelsPerInch ?? 264)
//        let screenPixelsPerMeter = Double(ppi) * inchesPerMeter
//        let resolution = Double(16)/screenPixelsPerMeter

class DrawingManager {
    var zoomLevel : UInt
    var tractorWidth : CGFloat
    var rowCount : Int
    var screenPixelsPerMeter : Double
    var metersPerPx : Double = 3
    let mapView : GMSMapView!
    var widthRatio : CGFloat = 0
    var hieghtRatio : CGFloat = 0
    
    init(with tractorWidth : CGFloat, rowCount : Int, mapView : GMSMapView) {
        let ppi = (UIScreen.pixelsPerInch ?? 264)
        self.screenPixelsPerMeter = Double(ppi) * inchesPerMeter
        zoomLevel = 16
        self.tractorWidth = tractorWidth
        self.rowCount = rowCount
        self.mapView = mapView
    }
    
    var zoom : UInt {
        get {
            return zoomLevel
        }
        set {
            zoomLevel = newValue
        }
    }
    
    func getDrawPoint(with mapView : GMSMapView, cachedTile : ICEMapTile, from coord : CLLocationCoordinate2D) -> CGPoint {
        let mapPoint = mapView.projection.point(for: coord)
        
        let northWestTileOriginScreenPt = mapView.projection.point(for: cachedTile.northWest)
        let southEastTileOriginScreenPt = mapView.projection.point(for: cachedTile.southEast)
        
        // translation
        let tileWidth = southEastTileOriginScreenPt.x - northWestTileOriginScreenPt.x
        let tileHeight = southEastTileOriginScreenPt.y - northWestTileOriginScreenPt.y
        
        // transformation
        widthRatio = TileSize / tileWidth
        hieghtRatio = TileSize / tileHeight
        
        let xOffset = (mapPoint.x - northWestTileOriginScreenPt.x) * widthRatio
        let yOffset = (mapPoint.y - northWestTileOriginScreenPt.y) * hieghtRatio
        
        let drawPoint = CGPoint(x: xOffset, y: yOffset)
        return drawPoint
    }
    
    func drawRow(at coord : CLLocationCoordinate2D) -> Bool {
        metersPerPx = 156543.03392 * cos(coord.latitude * Double.pi / 180) / pow(2, Double(zoomLevel))
        let tilePt = MBUtils.createInfoWindowContent(latLng: coord, zoom: zoomLevel)
        
        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: UInt(zoomLevel))
        guard let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile else {
            return false
        }
        let drawPoint = getDrawPoint(with: mapView, cachedTile: cachedTile, from: coord)
        
        if let newImage = drawRectangleOnImage(image: cachedTile.image, atPoint: drawPoint) {
            cachedTile.image = newImage
            return true
        }
        return false
    }
    
    func drawRectangleOnImage(image : UIImage, atPoint point : CGPoint) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in

            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.1)
            
            image.draw(at: CGPoint.zero)
            let partsWidth = (CGFloat(tractorWidth) / CGFloat(self.metersPerPx)) / widthRatio
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
