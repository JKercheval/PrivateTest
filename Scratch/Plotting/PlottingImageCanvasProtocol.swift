//
//  PlottingImageCanvasProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/2/20.
//

import Foundation
import UIKit
import CoreLocation

protocol PlottingImageCanvasProtocol {
    var currentImage : UIImage? { get }
    var imageSize : CGSize { get }
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool
    func getSubImageFromCanvas(with subImageRect : CGRect) -> UIImage?
}

protocol MapViewProtocol {
    func point(for coord : CLLocationCoordinate2D) -> CGPoint
}

protocol MachineInfoProtocol {
    var machineWidth : Double { get }
    var numberOfRows : UInt { get }
}
