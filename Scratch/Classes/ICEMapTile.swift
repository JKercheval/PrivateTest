//
//  ICEMapTile.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/18/20.
//

import UIKit
import CoreLocation

class ICEMapTile: NSObject {
    var image : UIImage
    var topLeft : CLLocationCoordinate2D
    var bottomRight : CLLocationCoordinate2D
    
    init(withImage image: UIImage, topL : CLLocationCoordinate2D, bottomR : CLLocationCoordinate2D) {
        self.image = image
        self.topLeft = topL
        self.bottomRight = bottomR
        super.init()
    }
}
