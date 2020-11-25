//
//  UIView+Extension.swift
//  SeedSelector
//
//  Created by Jeremy Kercheval on 11/6/20.
//

import Foundation
import CoreLocation
import UIKit
import GoogleMaps

let LatLonEarthRadius : CLLocationDegrees = 6371010.0;
func radians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
func degrees(radians: Double) -> Double { return radians * 180.0 / .pi }

extension Notification.Name {
  static let didUpdateLocation = Notification.Name("didUpdateLocation")
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
