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
    
    
    /// requestTileForX:y:zoom:receiver: generates image tiles for GMSTileOverlay. It must be overridden
    /// by subclasses. The tile for the given |x|, |y| and |zoom| _must_ be later passed to |receiver|.
    /// Specify kGMSTileLayerNoTile if no tile is available for this location; or nil if a transient
    /// error occured and a tile may be available later.
    /// Calls to this method will be made on the main thread. See GMSSyncTileLayer for a base class that
    /// implements a blocking tile layer that does not run on your application's main thread.
    /// - Parameters:
    ///   - x: x location for the tile
    ///   - y: y location for the tile
    ///   - zoom: zoom level for the tile
    ///   - receiver: GMSTileReceiver which is called when the tile is retreived.
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
        let tileLoc = TileCoordinate(northWest: northWest, southEast: southEast)
        let image = self.imageServer.getImageForTile(tile: tilePt,tileLoc: tileLoc , zoom: zoom)
        receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: image)
    }
}
