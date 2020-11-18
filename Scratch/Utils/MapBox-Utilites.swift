//
//  MapBox-Utilites.swift
//  SeedSelector
//
//  Created by Jeremy Kercheval on 11/13/20.
//

import Foundation
import GEOSwift
import CoreLocation
import Mapbox

func radians(degrees: Double) -> Double { return degrees * .pi / 180.0 }

class MBUtils {
  static func loadGeoJson(jsonFileName : String) ->Data {

    // Get the path for example.geojson in the app’s bundle.
      guard let jsonUrl = Bundle.main.url(forResource: jsonFileName, withExtension: "geojson") else {
        preconditionFailure("Failed to load local GeoJSON file")
      }
      
      guard let jsonData = try? Data(contentsOf: jsonUrl) else {
        preconditionFailure("Failed to parse GeoJSON file")
      }
    
    return jsonData
  }
  
  static func stringForCaching(withPoint point: CGPoint, zoomLevel : UInt) -> String {
    return "\(point.x)_\(point.y)_\(zoomLevel)"
  }
  
  static func createFirstImage(size: CGSize) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { ctx in
      // Create the image with a transparent background
      ctx.cgContext.setFillColor(UIColor.red.cgColor)
      ctx.cgContext.setAlpha(0.2)
      ctx.cgContext.fill(CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    }
    return img
  }

}

class GeoJSONField {
  private var jsonData : Data?
  
  var data : Data? {
    get {
      return jsonData
    }
  }
  
  var fieldEnvelope : Envelope? {
    get {
      guard let data = jsonData, let geoJson = try? JSONDecoder().decode(GeoJSON.self, from: data) else {
        return nil
      }
      switch (geoJson) {
        case .featureCollection(let featureCollection):
          let feild = featureCollection.features.first?.geometry
          return try? feild?.envelope()
        case .feature(_):
          break
        case .geometry(_):
          break
      }
      return nil
    }
  }
  
  var topLeft : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.maxY, longitude: envelope.minX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var bottomLeft : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.minX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var bottomRight : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.maxX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var topRight : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.maxY, longitude: envelope.maxX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  init(fieldName : String) {
    jsonData = MBUtils.loadGeoJson(jsonFileName: fieldName)
  }
}

class FieldGpsGenerator {
  var timer = Timer()
  private var fieldBoundary : Envelope = Envelope(minX: 0, maxX: 0, minY: 0, maxY: 0)
  private var currentLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()

  init(fieldBoundary : Envelope) {
    self.fieldBoundary = fieldBoundary
    self.currentLocation = self.startLocation
  }

  var startLocation : CLLocationCoordinate2D {
    get {
      return CLLocationCoordinate2D(latitude: fieldBoundary.minY, longitude: fieldBoundary.minX)
    }
  }

  private var endLocation : CLLocationCoordinate2D {
    get {
      return CLLocationCoordinate2D(latitude: fieldBoundary.maxY, longitude: fieldBoundary.minX)
    }
  }
  
  func start() {
    debugPrint("\(self):\(#function) - Curent location is: \(currentLocation)")
    let nextLoc = self.startLocation.locationWithBearing(bearingRadians: radians(degrees: 0), distanceMeters: 1)
    //calculateCoordinateFrom(self.startLocation, 0, 1)
    debugPrint("\(self):\(#function) - Next location is: \(nextLoc)")
    NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: nextLoc)
    currentLocation = nextLoc
    debugPrint("\(self):\(#function) - new curent location is: \(currentLocation)")
    timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateNextCoord), userInfo: nil, repeats: true)
  }

  @objc func updateNextCoord() {
    let nextLoc = self.currentLocation.locationWithBearing(bearingRadians: radians(degrees: 0), distanceMeters: 1)
    // calculateCoordinateFrom(self.currentLocation, 0, 1)
    NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: nextLoc)
    currentLocation = nextLoc
    debugPrint("\(#function) - new curent location is: \(currentLocation)")
    if currentLocation.latitude > endLocation.latitude {
      stop()
    }
  }
  
  func stop() {
    debugPrint("\(#function) - Stopped timer")
    timer.invalidate()
    timer = Timer()
  }

}


class TractorAnnotationView: MGLAnnotationView {
  let tractorImage = UIImage(named: "Planter")
  var imageView : UIImageView!
  
  init(reuseIdentifier: String, size: CGFloat) {
    super.init(reuseIdentifier: reuseIdentifier)
    imageView = UIImageView(image: tractorImage)
    imageView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: size * 0.48, height: size))
    self.addSubview(imageView)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class PlottedImageAnnotationView: MGLAnnotationView {
  var plottingImage : UIImage!
  var imageView : UIImageView!
  var mapView : MGLMapView!
  
  init(reuseIdentifier: String, mapView: MGLMapView, size: CGSize) {
    super.init(reuseIdentifier: reuseIdentifier)
    debugPrint("\(self)\(#function)")
    self.mapView = mapView
    guard let image = createFirstImage(size: size) else {
      return
    }
    plottingImage = image
    imageView = UIImageView(image: plottingImage)
    imageView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
    self.addSubview(imageView)
    
    NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.didUpdateLocation, object: nil)

  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ rect: CGRect) {
    super.draw(rect)
    debugPrint("\(self):\(#function)")
  }
  
  @objc func ondidUpdateLocation(_ notification:Notification) {
    //    debugPrint("\(#function)")
    let coord = notification.object as! CLLocationCoordinate2D
    
    let drawPoint = self.self.mapView.convert(coord, toPointTo: self)
    debugPrint("\(#function) - drawPoint is \(drawPoint)")
//    let drawPoint = CGPoint(x: plottingImageReferencePoint.x - startingPoint.x, y: plottingImageReferencePoint.y - startingPoint.y)
    self.plottingImage = drawRectangleOnImage(image: plottingImage, atPoint: drawPoint)
    self.imageView.setNeedsDisplay()
//    source.image = self.plottingImage
    
//    currentYlocation += 10
    
    //    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
    //      self.pointAnnotation.coordinate = coord
    //      self.mglMapView?.addAnnotation(self.pointAnnotation)
    //
    //    } completion: { (success) in
    //
    //    }
    
  }
  func createFirstImage(size: CGSize) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: size)
    let img = renderer.image { ctx in
      // Create the image with a transparent background
      ctx.cgContext.setFillColor(UIColor.red.cgColor)
      ctx.cgContext.setAlpha(0.2)
      ctx.cgContext.fill(CGRect(origin: CGPoint(x: 0, y: 0), size: size))
    }
    return img
  }
  
  // TEST CODE
  func drawRectangleOnImage(image : UIImage, atPoint point : CGPoint) -> UIImage? {
    let rowCount : Int = 96
    
    let renderer = UIGraphicsImageRenderer(size: image.size)
    let img = renderer.image { ctx in
      
      ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
      ctx.cgContext.setLineWidth(0.1)
      
      image.draw(at: CGPoint.zero)
      //      let partsWidth = (image.size.width - 20) / CGFloat(rowCount) / CGFloat(self.groundResolution)
      let partsWidth = (90) / CGFloat(rowCount) / CGFloat(1.7835797061735517)
      let startX : CGFloat = point.x
      for n in 0..<rowCount {
        var color = UIColor.black.cgColor
        if n % 2 == 0 {
          color = UIColor.red.cgColor
        }
        ctx.cgContext.setFillColor(color)
        let rect = CGRect(x: startX + (partsWidth * CGFloat(n)), y: point.y, width: partsWidth, height: partsWidth)
        ctx.cgContext.fill(rect)
      }
    }
    return img
  }
}
