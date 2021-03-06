import Foundation
import CoreLocation
import UIKit
import GoogleMaps

let LatLonEarthRadius : CLLocationDegrees = 6371010.0;
func radians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
func degrees(radians: Double) -> Double { return radians * 180.0 / .pi }

let userInfoDataReceivedKey = "DataReceived"
let userInfoStatusReceivedKey = "StatusReceived"
let userInfoPlottedCoordinateKey = "PlottedCoordinate"
let userInfoPlottedRowKey = "plottedRow"
let userInfoDisplayTypeKey = "displayType"
let userInfoSessionStartKey = "sessionStart"
let userInfoSessionDataReceivedKey = "sessionDataReceived"
let userInfoPlotSessionDataKey = "sessionData"

extension Notification.Name {
    static let didReceiveData = Notification.Name("didReceiveData")
    static let newPlottedRow = Notification.Name("newPlottedRow")
    static let plotNewRow = Notification.Name("plotNewRow")
    static let didPlotRowNotification = Notification.Name("didPlotRow")
    static let didChangeDisplayTypeNotification = Notification.Name("didChangeDisplayType")
    static let switchDisplayTypeNotification = Notification.Name("switchDisplayType")
    static let dashboardAlertNotification = Notification.Name("dashboardAlert")
    static let sessionStartNotification = Notification.Name("sessionStart")
    // Session Data not yet decoded
    static let sessionDataMessageNotification = Notification.Name("sessionDataMessage")
    static let newSessionDataRowNotification = Notification.Name("newSessionDataRow")
    static let plotSessionDataNotification = Notification.Name("plotSessionData")
}

/// UIView extension fpr gettomg parent view controller.
extension UIView {
  var parentViewController: UIViewController? {
    var parentResponder: UIResponder? = self
    while parentResponder != nil {
      parentResponder = parentResponder!.next
      if let viewController = parentResponder as? UIViewController {
        return viewController
      }
    }
    return nil
  }
}

extension UIView {
  @IBInspectable var borderColor: UIColor? {
    get {
      return layer.borderColor.map(UIColor.init)
    }
    set {
      layer.borderColor = newValue?.cgColor
    }
  }
  @IBInspectable var borderWidth: CGFloat {
    get {
      return layer.borderWidth
    }
    set {
      layer.borderWidth = newValue
    }
  }
  
  @IBInspectable var cornerRadius: CGFloat {
    get {
      return layer.cornerRadius
    }
    set {
      layer.cornerRadius = newValue
    }
  }
}

extension UIView{
    func setAnchorPoint(anchorPoint: CGPoint) {
        
        var newPoint = CGPoint(x: self.bounds.size.width * anchorPoint.x, y: self.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: self.bounds.size.width * self.layer.anchorPoint.x, y: self.bounds.size.height * self.layer.anchorPoint.y)
        
        newPoint = newPoint.applying(self.transform)
        oldPoint = oldPoint.applying(self.transform)
        
        var position : CGPoint = self.layer.position
        
        position.x -= oldPoint.x
        position.x += newPoint.x;
        
        position.y -= oldPoint.y;
        position.y += newPoint.y;
        
        self.layer.position = position;
        self.layer.anchorPoint = anchorPoint;
    }
}
