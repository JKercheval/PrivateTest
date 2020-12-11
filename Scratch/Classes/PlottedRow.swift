import Foundation
import UIKit
import CoreLocation

typealias PlottedRowValues = Array<CGFloat>

protocol PlottedRowInfoProtocol {
    var plottingCoordinate : CLLocationCoordinate2D { get }
    var heading : Double { get }
    var rowInfo : PlottedRowValues { get }
    var nextPlottedRow : PlottedRowInfoProtocol? { get set }
}

class PlottedRow : PlottedRowInfoProtocol {
    private var plottedRowLocation : CLLocationCoordinate2D!
    private var rowInfoArr : PlottedRowValues!
    private var rowHeading : Double = 0
    
    var nextPlottedRow: PlottedRowInfoProtocol?

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
