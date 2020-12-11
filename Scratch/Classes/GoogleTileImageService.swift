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
