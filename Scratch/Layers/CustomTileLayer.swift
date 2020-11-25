//
//  CustomTileLayer.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/19/20.
//

import Foundation
import GoogleMaps
import PINCache

protocol CWGMSTileLayerDelegate {
    
    func requestedZoomLevelChanged(with newZoom : UInt)
}

class CustomTileLayer: GMSTileLayer {
    var tileDictionary : TileRectMap!
    var lastRequestedZoomLevel : UInt = 0
    var delegate : CWGMSTileLayerDelegate?
    var imageServer : TileImageSourceServer!
    
    init(tileDictionary : TileRectMap, imageServer : TileImageSourceServer) {
        self.tileDictionary = tileDictionary
        self.imageServer = imageServer
    }
    override func requestTileFor(x: UInt, y: UInt, zoom: UInt, receiver: GMSTileReceiver) {
        if lastRequestedZoomLevel != zoom {
            lastRequestedZoomLevel = zoom
            guard let theDelegate = delegate else {
                return
            }
            theDelegate.requestedZoomLevelChanged(with: lastRequestedZoomLevel)
        }
        let tilePt = CGPoint(x: Int(x), y: Int(y))
        let northWest = MBUtils.topLeftCorner(with: tilePt, zoom)
        let southEast = MBUtils.topLeftCorner(with: CGPoint(x: tilePt.x + 1, y: tilePt.y + 1), zoom)
//        debugPrint("\(#function) Tile coordinate is: \(tilePt), zoom is \(zoom)")
//        guard let boundary = tileDictionary.tileRectDictionary[zoom] else {
//            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
//            return
//        }
//        guard boundary.contains(tilePt) else {
//            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: kGMSTileLayerNoTile)
//            debugPrint("\(self)\(#function) Tile not in our boundary !!!")
//
//            return
//        }
        let tileLoc = TileCoordinate(northWest: northWest, southEast: southEast)
        let image = self.imageServer.getImageForTile(tile: tilePt,tileLoc: tileLoc , zoom: zoom)
//        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
//        if let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile {
//            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: cachedTile.image)
//            return
//        }
//
//        let northWest = MBUtils.topLeftCorner(with: tilePt, zoom)
//        let southEast = MBUtils.topLeftCorner(with: CGPoint(x: tilePt.x + 1, y: tilePt.y + 1), zoom)
//
//        guard let image = MBUtils.createFirstImage(size: CGSize(width: TileSize, height: TileSize)) else {
//            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
//            return
//        }
//
//        let tile = ICEMapTile(withImage: image, northWest: northWest, southEast: southEast)
//        PINMemoryCache.shared.setObject(tile, forKey: key)
        receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: image)
    }
}

class CustomSyncTileLayer: GMSSyncTileLayer {
    var tileDictionary : TileRectMap!
    init(tileDictionary : TileRectMap) {
        self.tileDictionary = tileDictionary
    }
    
    override func tileFor(x: UInt, y: UInt, zoom: UInt) -> UIImage? {
        let tilePt = CGPoint(x: Int(x), y: Int(y))
        //        debugPrint("\(#function) Tile coordinate is: \(tilePt), zoom is \(zoom)")
        guard let boundary = tileDictionary.tileRectDictionary[zoom] else {
            return nil
        }
        guard boundary.contains(tilePt) else {
            return kGMSTileLayerNoTile
        }
        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
        if let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile {
            return cachedTile.image
        }
        
        let northWest = MBUtils.topLeftCorner(with: tilePt, zoom)
        let southEast = MBUtils.topLeftCorner(with: CGPoint(x: tilePt.x + 1, y: tilePt.y + 1), zoom)
        
        guard let image = MBUtils.createFirstImage(size: CGSize(width: TileSize, height: TileSize)) else {
            return nil
        }
        
        let tile = ICEMapTile(withImage: image, northWest: northWest, southEast: southEast)
        PINMemoryCache.shared.setObject(tile, forKey: key)
        return image
    }
}
