//
//  PlottedRowImpl.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/14/20.
//

import Foundation
import CoreLocation

class PlottedRowImpl : PlottedRowInfoProtocol {
    private var base : PlottedRowBase!
    var nextPlottedRow: PlottedRowInfoProtocol?
    
    init(baseRow : PlottedRowBase) {
        base = baseRow
    }
    
    var plottingCoordinate: CLLocationCoordinate2D {
        return base.location!
    }
    
    var heading: Double {
        return base.rowHeading
    }
    
    var masterRowState: Bool {
        return base.masterRowState
    }

    var speed: Double {
        return base.speed
    }
    
    func isWorkStateOnForRowIndex(index : Int) -> Bool {
        assert(index < base.dataInfo.count, "Index is out of range!")
        let dataInfo = base.dataInfo[index]
        assert(index == dataInfo.rowId, "Row ID and index do not match!")
        return dataInfo.rowState
    }
    
    func value(for rowIndex : Int, displayType : DisplayType) -> Float {
        let dataInfo = base.dataInfo[rowIndex]
        guard let value = dataInfo.rowVariables[displayType] else {
            return -Float.greatestFiniteMagnitude
        }
        assert(rowIndex == dataInfo.rowId, "Row ID and index do not match!")
        return value
    }
    
}
