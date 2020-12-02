//
//  PlottedRow.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/30/20.
//

import Foundation
import CoreLocation

typealias PlottedRowValues = Array<Double>

protocol PlottedRowInfoProtocol {
    var plottingCoordinate : CLLocationCoordinate2D { get }
    var heading : Double { get }
    var rowInfo : PlottedRowValues { get }
}

class PlottedRow : PlottedRowInfoProtocol {
    
    private var plottedRowLocation : CLLocationCoordinate2D!
    private var rowInfoArr : PlottedRowValues!
    private var rowHeading : Double = 0
    
    init(plotCoord : CLLocationCoordinate2D, heading : Double, rowValues : PlottedRowValues) {
        plottedRowLocation = plotCoord
        rowInfoArr = rowValues
        rowHeading = heading
    }

    var plottingCoordinate: CLLocationCoordinate2D {
        return plottedRowLocation
    }
    
    var heading: Double {
        return rowHeading
    }
    
    var rowInfo: PlottedRowValues {
        return rowInfoArr
    }

}
