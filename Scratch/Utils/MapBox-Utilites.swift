import Foundation
import GEOSwift
import CoreLocation
import Mapbox

let TileSize : CGFloat = 512.0

struct CartesianExtents2D {
    var XMinimum : CGFloat
    var XMaximum : CGFloat
    var YMinimum : CGFloat
    var YMaximum : CGFloat
}

class TileRectMap {
    var tileRectDictionary : [UInt : CGRect] = [UInt : CGRect]()
}

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
    
    static func topLeftCorner(with tilePt : CGPoint, _ zoomLevel : UInt) -> CLLocationCoordinate2D {
        let pow2z = pow(2.0, Double(zoomLevel))
        let xRangeRatio = Double(tilePt.x) / pow2z
        let yRangeRatio = Double(tilePt.y) / pow2z
        let lon = xRangeRatio * 360 - 180
        let pi = Double.pi
        let lat = atan(sinh(pi - yRangeRatio * 2 * pi)) * 180 / pi
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    class func convertToScreen(point : CGPoint, extents : CartesianExtents2D, containerWidth : CGFloat, containerHeight : CGFloat) -> CGPoint {
        let x = (point.x - extents.XMinimum) * containerWidth / (extents.XMaximum - extents.XMinimum);
        let y = (extents.YMaximum - point.y) * containerHeight / (extents.YMaximum - extents.YMinimum);
        return CGPoint(x: x, y: y)
    }
    
    class func convertToViewport(point : CGPoint, extents : CartesianExtents2D, containerWidth : CGFloat, containerHeight : CGFloat ) -> CGPoint {
        let x = extents.XMinimum + (point.x * (extents.XMaximum - extents.XMinimum)) / containerWidth;
        let y = extents.YMaximum - (point.y * (extents.YMaximum - extents.YMinimum)) / containerHeight;
        return CGPoint(x: x, y: y)
    }

    class func getPixelCoordinates(latLng: CLLocationCoordinate2D, zoom: UInt) -> CGPoint {
        let scale = 1 << zoom
        let worldCoordinate = project(latLng: latLng)
        let pixelCoordinate = CGPoint(
            x: floor(worldCoordinate.x * CGFloat(scale)),
            y: floor(worldCoordinate.y * CGFloat(scale))
        )
        return pixelCoordinate
    }
    
    class func getCoordRect(forZoomLevel zoom : UInt, northWest : CLLocationCoordinate2D,
                            northEast : CLLocationCoordinate2D,
                            southEast : CLLocationCoordinate2D) -> CGRect {
        
        let topLeft = createInfoWindowContent(latLng: northWest, zoom: zoom)
        let topRight = createInfoWindowContent(latLng: northEast, zoom: zoom)
        let bottomRight = createInfoWindowContent(latLng: southEast, zoom: zoom)
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }

    
    /// Takes the CLLocationCoordinate2D for the location interested in and creates a CGPoint
    /// for the tile coordinate (coordinate in the grid): See
    /// https://developers.google.com/maps/documentation/javascript/examples/map-coordinates
    /// - Parameters:
    ///   - latLng: CLLocationCoordinate2D of the location
    ///   - zoom: Zoom level for tile coordinate
    /// - Returns: CGPoint of the tile in the world tile grid.
    class func createInfoWindowContent(latLng: CLLocationCoordinate2D, zoom: UInt) -> CGPoint {
        let scale = 1 << zoom;
        
        let worldCoordinate = project(latLng: latLng)
//        let pixelCoordinate = getPixelCoordinates(latLng: latLng, zoom: zoom)
        
        let tileCoordinate = CGPoint(
            x: floor((worldCoordinate.x * CGFloat(scale)) / CGFloat(TileSize)),
            y: floor((worldCoordinate.y * CGFloat(scale)) / CGFloat(TileSize))
        );
        
        return tileCoordinate
    }
    
    /// The mapping between latitude, longitude and pixels is defined by the web
    /// mercator projection: from
    /// https://developers.google.com/maps/documentation/javascript/examples/map-coordinates
    /// - Parameter latLng: CLLocationCoordinate2D coodinate for the location for the mapping
    /// - Returns: CGPoint of the world coordinate.
    private class func project(latLng: CLLocationCoordinate2D) -> CGPoint {
        var siny = sin((latLng.latitude * Double.pi) / 180);
        
        // Truncating to 0.9999 effectively limits latitude to 89.189. This is
        // about a third of a tile past the edge of the world tile.
        siny = min(max(siny, -0.9999), 0.9999);
        let xPt = TileSize * CGFloat((0.5 + latLng.longitude / 360))
        let yPt = CGFloat(Double(TileSize) * (0.5 - log((1 + siny) / (1 - siny)) / (4 * Double.pi)))
        return CGPoint(x: xPt, y: yPt)
    }
}

public struct Stopwatch {
    private var startTime: TimeInterval
    
    /// Initialize with current time as start point.
    public init() {
        startTime = CACurrentMediaTime()
    }
    
    /// Reset start point to current time
    public mutating func reset() {
        startTime = CACurrentMediaTime()
    }
    
    /// Calculate elapsed time since initialization or last call to `reset()`.
    ///
    /// - returns: `NSTimeInterval`
    public func elapsedTimeInterval() -> TimeInterval {
        return CACurrentMediaTime() - startTime
    }
    
    /// Get elapsed time in textual form.
    ///
    /// If elapsed time is less than a second, it will be rendered as milliseconds.
    /// Otherwise it will be rendered as seconds.
    ///
    /// - returns: `String`
    public func elapsedTimeString() -> String {
        let interval = elapsedTimeInterval()
        if interval < 1.0 {
            return NSString(format:"%.1f ms", Double(interval * 1000)) as String
        }
        else {
            return NSString(format:"%.2f s", Double(interval)) as String
        }
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
  
  var northWest : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.maxY, longitude: envelope.minX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var southWest : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.minX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var southEast : CLLocationCoordinate2D {
    get {
      if let envelope = fieldEnvelope {
        return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.maxX)
      }
      return CLLocationCoordinate2D()
    }
  }
  
  var northEast : CLLocationCoordinate2D {
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
    
    NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.newPlottedRow, object: nil)

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
