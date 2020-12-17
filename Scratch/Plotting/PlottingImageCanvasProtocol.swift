import Foundation
import UIKit
import CoreLocation
import GoogleMapsUtils

protocol PlottingImageCanvasProtocol {
    var currentCGImage : CGImage? { get }
    var machineWidth : Double { get }
    var imageSize : CGSize { get }
    var lastRowBound : GMSCoordinateBounds? { get }
    func image(forDisplayType type : DisplayType) -> CGImage?
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool
    func getSubImageFromCanvas(with subImageRect : CGRect) -> UIImage?
    func reset()
}

protocol MapViewProtocol {
    func point(for coord : CLLocationCoordinate2D) -> CGPoint
    func points(forMeters meters: Double, at location: CLLocationCoordinate2D) -> CGFloat
}

protocol MachineInfoProtocol {
    var machineWidth : Double { get }
    var numberOfRows : UInt { get }
}
