//
//  UIColor+Extension.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 12/17/20.
//

import Foundation
import UIKit

extension Float {
    func normalize(min: Float, max: Float, from a: Float = 0, to b: Float = 1) -> Float {
        return (b - a) * ((self - min) / (max - min)) + a
    }
}

extension UIColor {
    
    
    /// Method to help get a color value for a specific DisplayType
    /// - Parameters:
    ///   - value: the value of the row for which we need a color
    ///   - displayType: DisplayType
    /// - Returns: CGColor representing the UIColor for the value/DisplayType combination
    class func color(forValue value : Float, displayType : DisplayType) -> CGColor {
        switch displayType {
            case .singulation:
                let hue = value.normalize(min: 0.18, max: 0.22) * 0.33
                let color = UIColor(hue: CGFloat(hue), saturation: 1.0, brightness: 1.0, alpha: 1.0)
                return color.cgColor
            case .rideQuality:
                let hue = value.normalize(min: 0.70, max: 1.0) * 0.33
                let color = UIColor(hue: CGFloat(hue), saturation: 1.0, brightness: 1.0, alpha: 1.0)
                return color.cgColor
            case .downforce:
                let hue = value.normalize(min: 175.0, max: 300.0) * 0.33
                let color = UIColor(hue: CGFloat(hue), saturation: 1.0, brightness: 1.0, alpha: 1.0)
                return color.cgColor
        }
    }
}
