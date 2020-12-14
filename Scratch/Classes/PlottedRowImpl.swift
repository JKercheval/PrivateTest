//
//  PlottedRowImpl.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/14/20.
//

import Foundation
import CoreLocation

protocol PlottedRowInfoProtocol {
    var plottingCoordinate : CLLocationCoordinate2D { get }
    var heading : Double { get }
    var rowInfo : PlottedRowData { get }
    var speed : Double { get }
    var nextPlottedRow : PlottedRowInfoProtocol? { get }
}

class PlottedRowImpl : PlottedRowInfoProtocol {
    private var base : PlottedRowBase!
    var nextPlottedRow: PlottedRowInfoProtocol?
    
//    init(plotCoord : CLLocationCoordinate2D, heading : Double, speed: Double, rowValues : DataRowValues) {
//        base = PlottedRowBase(location: plotCoord, heading: heading, speed: speed, rows: [1 : rowValues])
//    }
    
    init(baseRow : PlottedRowBase) {
        base = baseRow
    }
    
    var plottingCoordinate: CLLocationCoordinate2D {
        return base.location!
    }
    
    var heading: Double {
        return base.rowHeading
    }
    
    var rowInfo: PlottedRowData {
        return base.rowInfoArr
    }
    
    var speed: Double {
        return base.speed
    }
    
}
