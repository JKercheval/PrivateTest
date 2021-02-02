import Foundation
import UIKit
import CoreLocation
import GoogleMaps

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
