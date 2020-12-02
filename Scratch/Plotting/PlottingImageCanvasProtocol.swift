//
//  PlottingImageCanvasProtocol.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/2/20.
//

import Foundation
import UIKit

protocol PlottingImageCanvasProtocol {
    var currentImage : UIImage? { get }
    func drawRow(with plottedRow : PlottedRowInfoProtocol) -> Bool
    func getSubImageFromCanvas(with subImageRect : CGRect) -> UIImage?
}

protocol MachineInfoProtocol {
    var machineWidth : Double { get }
    var numberOfRows : UInt { get }
}
