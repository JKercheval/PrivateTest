//
//  PlottedRow.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/30/20.
//

import Foundation
import CoreLocation

typealias PlottedRowValues = Array<Double>

class PlottedRow {
    private var plottedRowLocation : CLLocationCoordinate2D!
    var heading : Double = 0
    
    init(plotCoord : CLLocationCoordinate2D, rowValues : Array<Double>) {
        plottedRowLocation = plotCoord
    }
    
    var coord : CLLocationCoordinate2D {
        return plottedRowLocation
    }
}
