//
//  PlottedRow.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/30/20.
//

import Foundation
import UIKit
import CoreLocation

typealias PlottedRowValues = Array<CGFloat>

struct PlottedRowBase : Codable {
    var location : CLLocationCoordinate2D?
    var rowInfoArr : PlottedRowValues?
    var rowHeading : Double
    
    enum CodingKeys: String, CodingKey {
        case location
        case rowInfoArr
        case rowHeading = "heading"
    }
    
    init(location : CLLocationCoordinate2D, heading : Double, rows: PlottedRowValues) {
        self.location = location
        self.rowHeading = heading
        self.rowInfoArr = rows
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        location = try values.decode(CLLocationCoordinate2D.self, forKey: .location)
        rowHeading = try values.decode(Double.self, forKey: .rowHeading)
        rowInfoArr = try values.decode(PlottedRowValues.self, forKey: .rowInfoArr)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        //        try container.encode(longitude, forKey: .longitude)
        try container.encode(self.rowHeading, forKey: .rowHeading)
        try container.encode(self.rowInfoArr, forKey: .rowInfoArr)
        
    }
}

protocol PlottedRowInfoProtocol {
    var plottingCoordinate : CLLocationCoordinate2D { get }
    var heading : Double { get }
    var rowInfo : PlottedRowValues { get }
    var nextPlottedRow : PlottedRowInfoProtocol? { get set }
}

class PlottedRow : PlottedRowInfoProtocol {
    private var base : PlottedRowBase!
    var nextPlottedRow: PlottedRowInfoProtocol?

    init(plotCoord : CLLocationCoordinate2D, heading : Double, rowValues : PlottedRowValues) {
        base = PlottedRowBase(location: plotCoord, heading: heading, rows: rowValues)
    }

    init(baseRow : PlottedRowBase) {
        base = baseRow
    }

    var plottingCoordinate: CLLocationCoordinate2D {
        return base.location!
    }
    
    var heading: Double {
        return base.rowHeading
    }
    
    var rowInfo: PlottedRowValues {
        return base.rowInfoArr!
    }

}
