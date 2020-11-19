//
//  GoogleMapsViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/18/20.
//

import UIKit
import GoogleMaps
import GoogleMapsUtils
import PINCache
//import UIScreenExtension - if we need to use this, then uncomment the Podfile line that
// declares UIScreenExtension

let TileSize : CGFloat = 512.0
let inchesPerMeter: Double = 39.37007874

class GoogleMapsViewController: UIViewController, GMSMapViewDelegate {
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    
    var geoField : GeoJSONField?
    var gMapView : GMSMapView!
    var boundingRect : CGRect = CGRect.zero
    var tileMap : TileRectMap = TileRectMap()
    var currentZoom : Float = 16.0
    var tileLayer : CustomTileLayer!
    var gpsGenerator : FieldGpsGenerator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PINMemoryCache.shared.removeAllObjects()
        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.didUpdateLocation, object: nil)
        
        // Do any additional setup after loading the view.
        
        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let feild = geoField else {
            return
        }
        // Do any additional setup after loading the view.
        // Create a GMSCameraPosition that tells the map to display the
        // coordinate -33.86,151.20 at zoom level 6.
        let camera = GMSCameraPosition.camera(withLatitude: feild.bottomLeft.latitude, longitude: feild.bottomLeft.longitude, zoom: currentZoom)
        
        gMapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        
        gMapView.delegate = self
        gMapView.mapType = .satellite
        self.view.insertSubview(gMapView, belowSubview: self.startButton)
        //        self.view.addSubview(gMapView)
        
        guard let path = Bundle.main.path(forResource: "FotF Plot E Boundary", ofType: "geojson") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        renderGeoJSON(withUrl: url)
        
        boundingRect = getCoordRect(forZoomLevel: UInt(currentZoom))
        tileMap.tileRectDictionary[UInt(currentZoom)] = boundingRect
        debugPrint("\(#function) - Bounding tile rect is: \(boundingRect)")
        
        tileLayer = CustomTileLayer(tileDictionary: self.tileMap)
        tileLayer.tileSize = Int(TileSize)
        tileLayer.opacity = 0.3
        tileLayer.fadeIn = false
        tileLayer.map = gMapView
        
        guard let envelope = geoField?.fieldEnvelope else {
            return
        }
        gpsGenerator = FieldGpsGenerator(fieldBoundary: envelope)
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
    @objc func ondidUpdateLocation(_ notification:Notification) {
        
        //        DispatchQueue.main.async { [weak self] in
        guard let mapView = self.gMapView else {
            return
        }
//        DispatchQueue.main.async { [weak self] in
//            guard let strongSelf = self else { return }
            let coord = notification.object as! CLLocationCoordinate2D
            let zoom = UInt(self.currentZoom)
            let tilePt = self.createInfoWindowContent(latLng: coord, zoom: zoom)
            
            let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
        guard let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile else {
                return
            }
//            struct FirstTimeMarkers {
//                static var firstTime = true
//            }
//            if FirstTimeMarkers.firstTime == true {
//                FirstTimeMarkers.firstTime = false
//                let marker = GMSMarker()
//                marker.position = cachedTile.topLeft
//                marker.map = mapView
//                let marker1 = GMSMarker()
//                marker1.position = cachedTile.bottomRight
//                marker1.map = mapView
//                if let bottomLeft = strongSelf.geoField?.bottomLeft {
//                    let marker = GMSMarker()
//                    marker.position = bottomLeft
//                    marker.map = mapView
//                }
//            }

//            let ppi = (UIScreen.pixelsPerInch ?? 264)
//            let screenPixelsPerMeter = Double(ppi) * inchesPerMeter
//            let resolution = Double(zoom)/screenPixelsPerMeter
            
            let mapPoint = mapView.projection.point(for: coord)
            let tileExtent = CartesianExtents2D(XMinimum: 0, XMaximum: 512, YMinimum: 0, YMaximum: 512)
            let screenExtent = CartesianExtents2D(XMinimum: self.gMapView.bounds.minX,
                                                  XMaximum: self.gMapView.bounds.maxX,
                                                  YMinimum: self.gMapView.bounds.minY,
                                                  YMaximum: self.gMapView.bounds.maxY)
            let drawPoint = MBUtils.convertToReal(point: mapPoint,
                                                     extents: tileExtent,
                                                     containerWidth: self.gMapView.bounds.width,
                                                     containerHeight: self.gMapView.bounds.height)
            let drawPoint1 = MBUtils.convertToReal(point: mapPoint,
                                                      extents: screenExtent,
                                                      containerWidth: self.gMapView.bounds.width,
                                                      containerHeight: self.gMapView.bounds.height)

            let drawPoint2 = MBUtils.convertToScreen(point: mapPoint,
                                                      extents: tileExtent,
                                                      containerWidth: self.gMapView.bounds.width,
                                                      containerHeight: self.gMapView.bounds.height)

            debugPrint("\(#function) MapPoint is:\(mapPoint), drawPoint is \(drawPoint), drawPoint1 is \(drawPoint1), drawPoint2 is \(drawPoint2)")
            if let newImage = self.drawRectangleOnImage(image: cachedTile.image, atPoint: drawPoint) {
                cachedTile.image = newImage
                self.tileLayer.clearTileCache()
            }
            //            PINMemoryCache.shared.setObject(newImage, forKey: key)
//        }
    }
    
    @IBAction func onStartButtonSelected(_ sender: Any) {
        gpsGenerator.step()
    }

    @IBAction func onStopButtonSelected(_ sender: Any) {
        gpsGenerator.stop()
    }

    /// Test method to add and remove markers for visual aid
    @IBAction func onMarkersButtonSelected(_ sender: Any) {
        struct StaticMarkerInfo {
            static var selected = false
            static var nwMarker : GMSMarker?
            static var seMarker : GMSMarker?
            static var currentLocMarker : GMSMarker?
        }
        let zoom = UInt(self.currentZoom)
        let tilePt = self.createInfoWindowContent(latLng: gpsGenerator.startLocation, zoom: zoom)
        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
        guard let cachedTile = PINMemoryCache.shared.object(forKey: key) as? ICEMapTile else {
            return
        }

        guard StaticMarkerInfo.selected else {
            StaticMarkerInfo.selected = true
            StaticMarkerInfo.nwMarker = GMSMarker(position: cachedTile.northWest)
            StaticMarkerInfo.seMarker = GMSMarker(position: cachedTile.southEast)
            StaticMarkerInfo.currentLocMarker = GMSMarker(position: gpsGenerator.startLocation)
            StaticMarkerInfo.currentLocMarker?.map = self.gMapView
            StaticMarkerInfo.seMarker?.map = self.gMapView
            StaticMarkerInfo.nwMarker?.map = self.gMapView
            return
        }
        StaticMarkerInfo.selected = false
        StaticMarkerInfo.seMarker?.map = nil
        StaticMarkerInfo.nwMarker?.map = nil
        StaticMarkerInfo.currentLocMarker?.map = nil
        StaticMarkerInfo.currentLocMarker = nil
        StaticMarkerInfo.seMarker = nil
        StaticMarkerInfo.nwMarker = nil
    }

    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
        //    debugPrint("\(#function) Zoom level is: \(position.zoom)")
        let zoomFloor = UInt(floor(position.zoom))
        let zoomCeil = UInt(ceil(position.zoom))
        if tileMap.tileRectDictionary.keys.contains(zoomCeil) == false {
            let bounds = getCoordRect(forZoomLevel: zoomCeil)
            tileMap.tileRectDictionary[zoomCeil] = bounds
        }
        if tileMap.tileRectDictionary.keys.contains(zoomFloor) == false {
            let bounds = getCoordRect(forZoomLevel: zoomFloor)
            tileMap.tileRectDictionary[zoomFloor] = bounds
        }
        self.currentZoom = position.zoom
    }
    
    func drawRectangleOnImage(image : UIImage, atPoint point : CGPoint) -> UIImage? {
        let rowCount : Int = 96
        // DONT DELETE FOR NOW
//        let ppi = (UIScreen.pixelsPerInch ?? 264)
//        let screenPixelsPerMeter = Double(ppi) * inchesPerMeter
//        let resolution = Double(16)/screenPixelsPerMeter
        
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in
            
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.1)
            
            image.draw(at: CGPoint.zero)
            //      let partsWidth = (image.size.width - 20) / CGFloat(rowCount) / CGFloat(self.groundResolution)
            let partsWidth : CGFloat = 5 //(90) / CGFloat(rowCount) / CGFloat(1.7835797061735517)
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

extension GoogleMapsViewController {
    
    func renderGeoJSON(withUrl url : URL) {
        
        let geoJsonParser = GMUGeoJSONParser(url: url)
        geoJsonParser.parse()
        
        let renderer = GMUGeometryRenderer(map: gMapView, geometries: geoJsonParser.features)
        renderer.render()
    }
    
    func getCoordRect(forZoomLevel zoom : UInt) -> CGRect {
        guard let field = geoField else {
            return CGRect.zero
        }
        
        let topLeft = createInfoWindowContent(latLng: field.topLeft, zoom: zoom)
        let topRight = createInfoWindowContent(latLng: field.topRight, zoom: zoom)
        let bottomRight = createInfoWindowContent(latLng: field.bottomRight, zoom: zoom)
        //    let bottomLeft = createInfoWindowContent(latLng: field.bottomLeft, zoom: 16)
        debugPrint("Pts are: \(topLeft), \(topRight), \(bottomRight)")
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }
    
    /// https://developers.google.com/maps/documentation/javascript/examples/map-coordinates
    func createInfoWindowContent(latLng: CLLocationCoordinate2D, zoom: UInt) -> CGPoint {
        let scale = 1 << zoom;
        
        let worldCoordinate = project(latLng: latLng);
        
        let pixelCoordinate = CGPoint(
            x: floor(worldCoordinate.x * CGFloat(scale)),
            y: floor(worldCoordinate.y * CGFloat(scale))
        );
        debugPrint("PixelCoodinate are :\(pixelCoordinate)")
        let tileCoordinate = CGPoint(
            x: floor((worldCoordinate.x * CGFloat(scale)) / CGFloat(TileSize)),
            y: floor((worldCoordinate.y * CGFloat(scale)) / CGFloat(TileSize))
        );
        
        return tileCoordinate
    }
    
    // The mapping between latitude, longitude and pixels is defined by the web
    // mercator projection.
    func project(latLng: CLLocationCoordinate2D) -> CGPoint {
        var siny = sin((latLng.latitude * Double.pi) / 180);
        
        // Truncating to 0.9999 effectively limits latitude to 89.189. This is
        // about a third of a tile past the edge of the world tile.
        siny = min(max(siny, -0.9999), 0.9999);
        let xPt = TileSize * CGFloat((0.5 + latLng.longitude / 360))
        let yPt = CGFloat(Double(TileSize) * (0.5 - log((1 + siny) / (1 - siny)) / (4 * Double.pi)))
        return CGPoint(x: xPt, y: yPt)
    }
}
