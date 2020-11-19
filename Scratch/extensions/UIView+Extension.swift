//
//  UIView+Extension.swift
//  SeedSelector
//
//  Created by Jeremy Kercheval on 11/6/20.
//

import Foundation
import CoreLocation
import UIKit

let LatLonEarthRadius : CLLocationDegrees = 6371010.0;

extension CLLocation {
    
    /// Get distance between two points
    ///
    /// - Parameters:
    ///   - from: first point
    ///   - to: second point
    /// - Returns: the distance in meters
    class func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let to = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return from.distance(from: to)
    }
}

extension CLLocationCoordinate2D: Equatable {
  static public func ==(lhs: Self, rhs: Self) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
  }
  
  fileprivate func radians(degrees: Double) -> Double { return degrees * .pi / 180.0 }
  fileprivate func degrees(radians: Double) -> Double { return radians * 180.0 / .pi }
  
  func boundingRect(bearing: Double, distanceInMeter distance: CLLocationDistance) -> [CLLocationCoordinate2D] {
    let top = coordinate(bearing: 0.0, distanceInMeter: distance);
    let right = coordinate(bearing: 90.0, distanceInMeter: distance);
    let left = coordinate(bearing: 270.0, distanceInMeter: distance);
    let bottom = coordinate(bearing: 180.0, distanceInMeter: distance);
    return [left, top, right, bottom]
  }
  
  func coordinate(bearing: Double, distanceInMeter distance: CLLocationDistance) -> CLLocationCoordinate2D {
    let kLatLonEarthRadius: CLLocationDegrees = 6371.0
    let brng: Double = radians(degrees: bearing)
    let lat1: Double = radians(degrees: self.latitude)
    let lon1: Double = radians(degrees: self.longitude)
    
    let lat2: CLLocationDegrees = asin(
      sin(lat1) * cos(distance / kLatLonEarthRadius) +
        cos(lat1) * sin(distance / kLatLonEarthRadius) * cos(brng)
    )
    
    var lon2: CLLocationDegrees = lon1 + atan2(
      sin(brng) * sin(distance / kLatLonEarthRadius) * cos(lat1),
      cos(distance / kLatLonEarthRadius) - sin(lat1) * sin(lat2)
    )
    lon2 = fmod(lon2 + .pi, 2.0 * .pi) - .pi
    
    var coordinate = CLLocationCoordinate2D()
    if !lat2.isNaN && !lon2.isNaN {
      coordinate.latitude = degrees(radians: lat2)
      coordinate.longitude = degrees(radians: lon2)
    }
    return coordinate
  }
  
  func rect(distanceInMeter meter: CLLocationDistance) -> (north: Double, west: Double, south: Double, east: Double) {
    let north = coordinate(bearing: 0, distanceInMeter: meter).latitude
    let south = coordinate(bearing: 180, distanceInMeter: meter).latitude
    let east = coordinate(bearing: 90, distanceInMeter: meter).longitude
    let west = coordinate(bearing: 270, distanceInMeter: meter).longitude
    
    return (north: north, west: west, south: south, east: east)
  }

  func quadRect(withDistance distance : Double) -> [CLLocationCoordinate2D] {
    let bounds = calculateBoundingCoordinates(withDistance: distance)
    //      let coords = coord.boundingRect(bearing: 0, distanceInMeter: CLLocationDistance(0.7))
    //      debugPrint("Bounding box coords are: \(coords)")
    let polygonShapeCoords = [
      CLLocationCoordinate2D(latitude: bounds.0.latitude, longitude: bounds.0.longitude),
      CLLocationCoordinate2D(latitude: bounds.1.latitude, longitude: bounds.0.longitude),
      CLLocationCoordinate2D(latitude: bounds.1.latitude, longitude: bounds.1.longitude),
      CLLocationCoordinate2D(latitude: bounds.0.latitude, longitude: bounds.1.longitude)
    ]
    return polygonShapeCoords
  }
  
  /// https://gist.github.com/jmcd/4502302
//  private func calculateCoordinateFrom(_ coordinate : CLLocationCoordinate2D, _ bearingInRadians : Double, _ distanceInMetres : Double) -> CLLocationCoordinate2D {
//    let coordinateLatitudeInRadians : Double = coordinate.latitude * Double.pi / 180;
//    let coordinateLongitudeInRadians : Double = coordinate.longitude * Double.pi / 180;
//    
//    let distanceComparedToEarth = distanceInMetres / 6378100;
//    
//    let resultLatitudeInRadians = asin(sin(coordinateLatitudeInRadians) * cos(distanceComparedToEarth) + cos(coordinateLatitudeInRadians) * sin(distanceComparedToEarth) * cos(bearingInRadians));
//    let resultLongitudeInRadians = coordinateLongitudeInRadians + atan2(sin(bearingInRadians) * sin(distanceComparedToEarth) * cos(coordinateLatitudeInRadians), cos(distanceComparedToEarth) - sin(coordinateLatitudeInRadians) * sin(resultLatitudeInRadians));
//    
//    var result : CLLocationCoordinate2D = CLLocationCoordinate2D()
//    result.latitude = resultLatitudeInRadians * 180 / Double.pi;
//    result.longitude = resultLongitudeInRadians * 180 / Double.pi;
//    return result;
//  }

  func locationWithBearing(bearingRadians:Double, distanceMeters:Double) -> CLLocationCoordinate2D {
    let distRadians = distanceMeters / (6372797.6) // earth radius in meters
    
    let lat1 = latitude * Double.pi / 180
    let lon1 = longitude * Double.pi / 180
    
    let lat2 = asin(sin(lat1) * cos(distRadians) + cos(lat1) * sin(distRadians) * cos(bearingRadians))
    let lon2 = lon1 + atan2(sin(bearingRadians) * sin(distRadians) * cos(lat1), cos(distRadians) - sin(lat1) * sin(lat2))
    
    return CLLocationCoordinate2D(latitude: lat2 * 180 / Double.pi, longitude: lon2 * 180 / Double.pi)
  }

  /**
   Calculates a bbox around this CLLocationCoordinat2D by describing a distance that is roughly analagous to
   the radius of a circle with a center at this coordinate and the radius is the distance and inscribes the circle
   to the bbox created.
   
   This tangential point method of calculating the box is described in Handbook of Mathematics By I.N. Bronshtein,
   K.A. Semendyayev, Gerhard Musiol, Heiner Mühlig
   - Remark: If you are using these coordinates to create a boolean based query you will need to take special note to check
   for the hemisphere of the corners.
   
   - Remark: Please email me at ray.pendergraph@gmx.com if you find issues with this implementation.
   
   - parameters:
   - distance: The radius of an inscribed circle on the desired bounding box centered on this coordinate.
   
   - returns: A tuple containing the southwest and northeast corners of the bbox respectively.
   */
  func calculateBoundingCoordinates(withDistance distance: Double) -> (CLLocationCoordinate2D, CLLocationCoordinate2D) {
    
    let minimumLatitude = -90.0 * Double.pi / 180.0
    let maximumLatitude = 90.0 * Double.pi / 180.0
    let minimumLongitude = -180.0 * Double.pi / 180.0
    let maximumLongitude = 180.0 * Double.pi / 180.0
    
    let latitudeInRadians = latitude * Double.pi / 180.0
    let longitudeInRadians = longitude * Double.pi / 180.0
    let radiusMeters = 6371010.0
    
    
    let angularDistance = distance / radiusMeters
    var minLat = latitudeInRadians - angularDistance
    var maxLat = latitudeInRadians + angularDistance
    var minLon = 0.0
    var maxLon = 0.0
    if minLat > minimumLatitude && maxLat < maximumLatitude {
      let deltaLongitude = asin( sin(angularDistance) ) / cos(latitudeInRadians)
      minLon = longitudeInRadians - deltaLongitude
      
      if (minLon < minimumLongitude) {
        minLon += 2.0 * Double.pi
      }
      
      maxLon = longitudeInRadians + deltaLongitude
      
      if maxLon > maximumLongitude {
        maxLon -= 2.0 * Double.pi
      }
    }
    else {
      minLat = max(minLat, minimumLatitude)
      maxLat = min(maxLat, maximumLatitude)
      minLon = minimumLongitude
      maxLon = maximumLongitude
    }
    
    let coordinateFromRadians : (Double, Double) -> CLLocationCoordinate2D = {
      (latRadians, lonRadians) in
      
      let latDegrees = CLLocationDegrees(latRadians * 180.0 / Double.pi)
      let lonDegrees = CLLocationDegrees(lonRadians * 180.0 / Double.pi)
      return CLLocationCoordinate2D(latitude: latDegrees, longitude: lonDegrees)
    }
    
    return (coordinateFromRadians(minLat, minLon), coordinateFromRadians(maxLat, maxLon))
  }
  
  func formatAsLatLonString(withDecimalPlaces places: Int = 5) -> (String, String) {
    
    let latitudeString: String = {
      if latitude > 0.0 {
        return String(format: "lat %.\(places)fN", fabs(latitude))
      }
      else {
        return String(format: "lat %.\(places)fS", fabs(latitude))
      }
    }()
    
    let longitudeString: String = {
      if latitude > 0.0 {
        return String(format: "lon %.\(places)fE", fabs(longitude))
      }
      else {
        return String(format: "lon %.\(places)fW", fabs(longitude))
      }
    }()
    
    return (latitudeString, longitudeString)
    
    
  }
}

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
