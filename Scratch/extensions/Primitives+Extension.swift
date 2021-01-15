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

extension TimeInterval {
    var milliseconds: Int {
        return Int((truncatingRemainder(dividingBy: 1)) * 1000)
    }
    
    var seconds: Int {
        return Int(self) % 60
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

protocol NameDescribable {
    var typeName: String { get }
    static var typeName: String { get }
}

extension NameDescribable {
    var typeName: String {
        return String(describing: type(of: self))
    }
    
    static var typeName: String {
        return String(describing: self)
    }
}

extension String {
    static var emptyString: String {
        return ""
    }
}
