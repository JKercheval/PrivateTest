//
//  Primitives+Extension.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/25/20.
//

import Foundation
import UIKit

extension CGContext {
    func drawFlipped(image: CGImage, rect: CGRect) {
        saveGState()
        translateBy(x: 0, y: rect.height)
        scaleBy(x: 1, y: -1)
        draw(image, in: rect)
        restoreGState()
    }
}

extension Float {
    var whole: Self { modf(self).0 }
    var fraction: Self { modf(self).1 }
}

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
 
    var radians: Double {
        return (self * Double.pi)/180.0
    }
}

extension CGFloat {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places:Int) -> CGFloat {
        let divisor = pow(10.0, Double(places))
        return CGFloat((Double(self) * divisor).rounded() / divisor)
    }
}
