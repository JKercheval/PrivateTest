//
//  CustomTileLayer.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/19/20.
//

import Foundation
import GoogleMaps
import PINCache

class CustomTileLayer: GMSTileLayer {
    var tileDictionary : TileRectMap!
    init(tileDictionary : TileRectMap) {
        self.tileDictionary = tileDictionary
    }
    override func requestTileFor(x: UInt, y: UInt, zoom: UInt, receiver: GMSTileReceiver) {
        let tilePt = CGPoint(x: Int(x), y: Int(y))
        debugPrint("\(#function) Tile coordinate is: \(tilePt), zoom is \(zoom)")
        guard let boundary = tileDictionary.tileRectDictionary[zoom] else {
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
            return
        }
        guard boundary.contains(tilePt) else {
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
            return
        }
        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
        if let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile {
            debugPrint("Using Cached image for \(key)")
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: cachedTile.image)
            return
        }
        
        let northWest = MBUtils.topLeftCorner(with: tilePt, zoom)
        let southEast = MBUtils.topLeftCorner(with: CGPoint(x: tilePt.x + 1, y: tilePt.y + 1), zoom)
        
        guard let image = MBUtils.createFirstImage(size: CGSize(width: TileSize, height: TileSize)) else {
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
            return
        }
        
        let tile = ICEMapTile(withImage: image, northWest: northWest, southEast: southEast)
        PINMemoryCache.shared.setObject(tile, forKey: key)
        receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: image)
    }
}
