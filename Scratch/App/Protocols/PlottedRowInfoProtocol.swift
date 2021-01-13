//
//  PlottedRowInfoProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 1/12/21.
//

import Foundation
import CoreLocation

protocol PlottedRowInfoProtocol {
    var plottingCoordinate : CLLocationCoordinate2D { get }
    var heading : Double { get }
    var speed : Double { get }
    var nextPlottedRow : PlottedRowInfoProtocol? { get }
    var masterRowState : Bool { get }
    func isWorkStateOnForRowIndex(index : Int) -> Bool
    func value(for rowIndex : Int, displayType : DisplayType) -> Float
}
