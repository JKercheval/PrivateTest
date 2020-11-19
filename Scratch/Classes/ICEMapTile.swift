//
//  ICEMapTile.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/18/20.
//

import UIKit
import CoreLocation
import GoogleMaps

class ICEMapTile: NSObject {
    var image : UIImage
    var bounds : GMSCoordinateBounds
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
    
    init(withImage image: UIImage, northWest : CLLocationCoordinate2D, southEast : CLLocationCoordinate2D) {
        self.image = image
        bounds = GMSCoordinateBounds(coordinate: northWest, coordinate: southEast)
        self.northWest = northWest
        self.southEast = southEast
        super.init()
    }
}
