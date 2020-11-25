//
//  GlobalMercator.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/21/20.
//

/*
 I'm am not sure yet if this class will be required or not, but there are a lot of useful methods for dealing with locations.
 Ported from this site: https://www.maptiler.com/google-maps-coordinates-tile-bounds-projection/
 */

import Foundation
struct CoordinatePair {
    var X : Double = 0
    var Y: Double = 0
}

struct TileAddress {
    var X : Double = 0
    var Y : Double = 0
}

struct GeoExtent {
    var North: Double = 0
    var South: Double = 0
    var East: Double = 0
    var West: Double = 0
}

class GlobalMercator {
    //Initialize the TMS Global Mercator pyramid
    private var tileSize : Double
    private var initialResolution : Double
    private var originShift : Double
    
    init(tileSize : Double) {
        self.tileSize = tileSize
        self.initialResolution = 2 * Double.pi * 6378137 / tileSize;
        self.originShift = 2 * Double.pi * 6378137 / 2.0
    }
    
    /// "Converts given lat/lon in WGS84 Datum to XY in Spherical Mercator EPSG:900913"
    func LatLonToMeters(lat : Double, lon : Double) -> CoordinatePair {
        var retval : CoordinatePair = CoordinatePair()
        retval.X = lon * self.originShift / 180.0;
        retval.Y = log(tan((90 + lat) * Double.pi / 360.0)) / (Double.pi / 180.0);
        
        retval.Y *= self.originShift / 180.0;
        return retval;
    }
    
    /// Converts lat/lon to pixel coordinates in given zoom of the EPSG:4326 pyramid
    func LatLonToPixels(lat : Double, lon : Double, zoom : UInt) -> CoordinatePair {
        let meters = self.LatLonToMeters(lat: lat, lon: lon)
        let metersPP = self.MetersToPixels(mx: meters.X, my: meters.Y, zoom: zoom)
        return metersPP
    }
    
    /// Converts XY point from Spherical Mercator EPSG:900913 to lat/lon in WGS84 Datum
    func MetersToLatLon(mx : Double, my : Double) -> CoordinatePair {
        let lon = (mx / self.originShift) * 180.0;
        var lat = (my / self.originShift) * 180.0;
        
        lat = 180 / Double.pi * (2 * atan(exp(lat * Double.pi / 180.0)) - Double.pi / 2.0);
        return CoordinatePair(X: lat, Y: lon);
    }
    
    ///
    func PixelsToLatLon(px : Double, py : Double, zoom : UInt) -> CoordinatePair {
        let meters = PixelsToMeters(px: px, py: py, zoom: zoom)
        return MetersToLatLon(mx: meters.X, my: meters.Y)
    }
    
    /// Converts pixel coordinates in given zoom level of pyramid to EPSG:900913
    func PixelsToMeters(px : Double, py : Double, zoom : UInt) -> CoordinatePair {
        var retval = CoordinatePair();
        let res = Resolution(zoom: zoom);
        retval.X = px * res - self.originShift;
        retval.Y = py * res - self.originShift;
        return retval;
    }
    
    /// Converts EPSG:900913 to pyramid pixel coordinates in given zoom level
    func MetersToPixels( mx : Double,  my : Double,  zoom : UInt) -> CoordinatePair {
        var retval = CoordinatePair();
        let res = Resolution(zoom: zoom);
        retval.X = (mx + self.originShift) / res;
        retval.Y = (my + self.originShift) / res;
        return retval;
    }
    
    /// Returns a tile covering region in given pixel coordinates
    func PixelsToTile(px : Double, py : Double) -> TileAddress {
        var retval = TileAddress();
        retval.X = ceil(Double(px / self.tileSize)) - 1
        retval.Y = ceil(Double(py / self.tileSize)) - 1
        return retval;
    }
    
    /// Returns tile for given mercator coordinates
    func MetersToTile(mx : Double, my : Double, zoom : UInt) -> TileAddress {
        var retval = TileAddress();
        let p = self.MetersToPixels(mx: mx, my: my, zoom: zoom);
        retval = self.PixelsToTile(px: p.X, py: p.Y);
        return retval;
    }
    
    func LatLonToTile(lat : Double, lon : Double, zoom : UInt) -> TileAddress {
        var retval = TileAddress();
        let m = self.LatLonToMeters(lat: lat, lon: lon);
        retval = self.MetersToTile(mx: m.X, my: m.Y, zoom: zoom);
        return retval;
    }
    
    func LatLonToTileXYZ(lat : Double, lon : Double, zoom : UInt) -> TileAddress {
        var retval = TileAddress();
        let m = self.LatLonToMeters(lat: lat, lon: lon);
        retval = self.MetersToTile(mx: m.X, my: m.Y, zoom: zoom);
        retval.Y = pow(2, Double(zoom)) - retval.Y - 1;
        return retval;
    }

    /// Returns bounds of the given tile in EPSG:900913 coordinates
    func TileBounds(tx : Double, ty : Double, zoom : UInt) -> GeoExtent {
        var retval : GeoExtent
        let min = self.PixelsToMeters(px: tx * self.tileSize, py: ty * self.tileSize, zoom: zoom);
        let max = self.PixelsToMeters(px: (tx + 1) * self.tileSize, py: (ty + 1) * self.tileSize, zoom: zoom);
        retval = GeoExtent(North: max.Y, South: min.Y, East: max.X, West: min.X)
        return retval
    }
    
    /// Returns bounds of the given tile in latutude/longitude using WGS84 datum
    func TileLatLonBounds(tx : Double, ty : Double, zoom : UInt) -> GeoExtent {
        var retval : GeoExtent
        let bounds = self.TileBounds(tx: tx, ty: ty, zoom: zoom);
        let min = self.MetersToLatLon(mx: bounds.West, my: bounds.South);
        let max = self.MetersToLatLon(mx: bounds.East, my: bounds.North);
        retval = GeoExtent(North: max.Y, South: min.Y, East: max.X, West: min.X)
        return retval;
    }
    
    func GoogleTile(tx : Double, ty : Double, zoom : UInt) -> TileAddress {
        var retval = TileAddress();
        retval.X = tx;
        retval.Y = (pow(2, Double(zoom)) - 1) - ty
        return retval;
    }
    
    /// Maximal scaledown zoom of the pyramid closest to the pixelSize
    func ZoomForPixelSize(pixelSize : Double) -> UInt {
        
        for i in 1...30 {
            if pixelSize > self.Resolution(zoom: UInt(i)) {
                return UInt(i-1)
            }
        }
        //        for i in range(30):
        //        if pixelSize > self.Resolution(i):
        //        return i-1 if i!=0 else 0 # We don't want to scale up
        return 0
    }

    func QuadTree(tx : Double, ty : Double, zoom : UInt) -> String {
        var retval = ""
        let ty = Double(((1 << zoom) - 1)) - ty;
        for i in stride(from: zoom, to: 1, by: -1) {
            var digit = 0;
            
            let mask = 1 << (i - 1);
            
            if ((UInt(tx) & mask) != 0) {
                digit += 1;
            }
            
            if ((UInt(ty) & mask) != 0) {
                digit += 2;
            }
            
            retval += "\(digit)"
        }
        
        return "\(retval)"
    }
    
    //    func QuadTreeToTile(quadtree : String, zoom : UInt) -> TileAddress {
    //        var retval = TileAddress();
    //        var tx = 0;
    //        var ty = 0;
    //
    //        for i in stride(from: zoom, to: 1, by: -1) {
    //            var ch = quadtree.index(quadtree.startIndex, offsetBy: Int(zoom - i))
    //            var mask = 1 << (i - 1);
    //
    //            var digit = ch - Int(String(ch));
    //
    //            if (Bool(digit & 1)) {
    //                tx += mask;
    //            }
    //
    //            if (Bool(digit & 2)) {
    //            ty += mask;
    //            }
    //        }
    //        //        for (var i = zoom; i >= 1; i--)
    //        for i in stride(from: zoom, to: 1, by: -1) {
    //            var ch = quadtree.index(quadtree.startIndex, offsetBy: Int(zoom - i))
    //            var mask = 1 << (i - 1);
    //            Int(String(ch))
    //            //        var digit = ch - '0';
    //            var digit = ch - Int(String(0))
    //
    //            if (Bool(digit & 1)) {
    //                tx += mask;
    //            }
    //
    //            if (Bool(digit & 2)) {
    //                ty += mask;
    //            }
    //        }
    //
    //        ty = ((1 << zoom) - 1) - ty;
    //        retval.X = tx;
    //        retval.Y = ty;
    //        return retval;
    //    }
    
    //    func LatLonToQuadTree(lat : Double, lon : Double, zoom : UInt) -> String
    //    {
    //        var retval = "";
    //
    //        var m = self.LatLonToMeters(lat, lon);
    //        var t = self.MetersToTile(m.X, m.Y, zoom);
    //
    //        retval = self.QuadTree(Convert.ToInt32(t.X), Convert.ToInt32(t.Y), zoom);
    //
    //        return retval;
    //    }
    
    /// Resolution (meters/pixel) for given zoom level (measured at Equator)
    private func Resolution(zoom : UInt) -> Double {
        return self.initialResolution / Double(1 << zoom)
    }
    
}

class GlobalGeodetic {
    var tileSize : UInt
    init(tileSize : UInt = 256) {
        self.tileSize = tileSize
    }
    
    /// Converts lat/lon to pixel coordinates in given zoom of the EPSG:4326 pyramid
    func LatLonToPixels(lat : Double, lon : Double, zoom : UInt) -> CoordinatePair {
        let res = 180 / 256.0 / Double(1 << zoom)
        let px = (180 + lat) / res
        let py = (90 + lon) / res
        return CoordinatePair(X: px, Y: py)
    }
    
    /// Returns coordinates of the tile covering region in pixel coordinates
    func PixelsToTile(px : Double, py : Double) -> TileAddress {
    
        let tx = Int( ceil( px / Double(self.tileSize) ) - 1 )
        let ty = Int( ceil( py / Double(self.tileSize) ) - 1 )
        return TileAddress(X: Double(tx), Y: Double(ty))
    }
    
    /// Resolution (arc/pixel) for given zoom level (measured at Equator)
    func resolution(zoom : UInt) -> Double {
        
        return 180 / 256.0 / Double(1 << zoom)
    }
}
