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

class GoogleMapViewImplementation: MapViewProtocol {
    
    private var mapView : GMSMapView!

    init(mapView : GMSMapView) {
        self.mapView = mapView
    }
    
    func point(for coord: CLLocationCoordinate2D) -> CGPoint {
        return mapView.projection.point(for: coord)
    }
}

class GoogleMapsViewController: UIViewController, GMSMapViewDelegate {
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var headingTextField: UITextField!
    @IBOutlet weak var stepperControl: UIStepper!
    
    // Set this to True to see our Google Tile implementation at work.
    var useGoogleTiles : Bool = false
    
    var geoField : GeoJSONField?
    var gMapView : GMSMapView!
    var boundingRect : CGRect = CGRect.zero
    var tileMap : TileRectMap = TileRectMap()
    var currentZoom : CGFloat = 16.0
    var tileLayer : CustomTileLayer!
    var gpsGenerator : FieldGpsGenerator!
    var drawingManager : DrawingManager!
    var imageSource : TileImageSourceServer?
    let serialQueue = DispatchQueue(label: "com.queue.serial")
    var stopWatch = Stopwatch()
    var fieldView : PlotDrawingView?
    var cheaterView : UIView!
    var boundaryQuad : FieldBoundaryCorners!
    var mapViewImpl : GoogleMapViewImplementation!
    
    
    fileprivate func initializeMapTileLayer(imageServer : TileImageSourceServer?) {
        guard let server = imageServer else {
            return
        }
        tileLayer = CustomTileLayer(imageServer: server)
        tileLayer.tileSize = Int(TileSize)
        tileLayer.opacity = 0.3
        tileLayer.fadeIn = false
        tileLayer.map = gMapView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        PINMemoryCache.shared.removeAllObjects()
        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.didUpdateLocation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        cheaterView = UIView(frame: CGRect.zero)
        
        // Do any additional setup after loading the view.
        
        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let field = geoField else {
            return
        }
        // Do any additional setup after loading the view.
        // Create a GMSCameraPosition that tells the map to display the
        // coordinate and zoom that we want
        let camera = GMSCameraPosition.camera(withLatitude: field.southWest.latitude, longitude: field.southWest.longitude, zoom: Float(currentZoom))
        gMapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        
        gMapView.delegate = self
        gMapView.settings.allowScrollGesturesDuringRotateOrZoom = false
//        gMapView.settings.rotateGestures = false
        gMapView.mapType = .satellite
        gMapView.setMinZoom(10, maxZoom: 22)

        mapViewImpl = GoogleMapViewImplementation(mapView: gMapView)
        
        self.view.insertSubview(gMapView, belowSubview: self.startButton)
        self.drawingManager = DrawingManager(with: CGFloat(54.0 * (3.0/inchesPerMeter)), rowCount: 54, mapView: gMapView)
        
        guard let path = Bundle.main.path(forResource: "FotF Plot E Boundary", ofType: "geojson") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        renderGeoJSON(withUrl: url)
        
        boundingRect = getCoordRect(forZoomLevel: UInt(currentZoom))
        tileMap.tileRectDictionary[UInt(currentZoom)] = boundingRect
        debugPrint("\(#function) - Bounding tile rect is: \(boundingRect)")
        guard let envelope = field.fieldEnvelope else {
            return
        }

        let boundsMaxZoom = getCoordRect(forZoomLevel: UInt(20))
        boundaryQuad = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)
        
        imageSource = TileImageSourceServer(with: boundsMaxZoom, boundQuad: boundaryQuad, mapView: mapViewImpl)

        if self.useGoogleTiles {
            initializeMapTileLayer(imageServer: imageSource)
        }
        
        gpsGenerator = FieldGpsGenerator(fieldBoundary: envelope)
        gpsGenerator.speed = 6.0 // mph
        self.headingTextField.text = "\(gpsGenerator.heading)"
//        let nwMarker = GMSMarker(position: boundary.northWest)
//        let seMarker = GMSMarker(position: boundary.southEast)
//        let neMarker = GMSMarker(position: boundary.northEast)
//        let swMarker = GMSMarker(position: boundary.southWest)
//        nwMarker.map = self.gMapView
//        seMarker.map = self.gMapView
//        neMarker.map = self.gMapView
//        swMarker.map = self.gMapView
    }
        
    /*
     // MARK: - Navigation
     
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */

    
    /*
     Notes:
        Maintain ZBuffer of space for draw coordinates, when required hand off the section
     */
    @objc func ondidUpdateLocation(_ notification:Notification) {
        guard let plottedRow = notification.userInfo?["plottedRow"] as? PlottedRowInfoProtocol else {
            return
        }
        
        serialQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.drawingManager.zoom = strongSelf.currentZoom
            // Passing in Zoom only to help with caching, which is not yet complete and commented out
            // in the TileImageSourceServer...
            let _ = strongSelf.imageSource?.drawRow(with: plottedRow, zoom: UInt(strongSelf.currentZoom))
        }
    }
    @IBAction func onStepperValueChanged(_ sender: Any) {
        guard let stepper = sender as? UIStepper else {
            debugPrint("\(self)\(#function) Failed to get Stepper")
            return
        }
        gpsGenerator.heading = Double(stepper.value)
        self.headingTextField.text = "\(gpsGenerator.heading)"
        debugPrint("\(self)\(#function) - Stepper value: \(stepper.value)")
    }
    
    @objc func onDidUpdateRow(_ notification:Notification) {
//        debugPrint("\(self)\(#function)")
        if self.useGoogleTiles {
            if stopWatch.elapsedTimeInterval().seconds < 1 {
                return
            }
            self.stopWatch.reset()
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.tileLayer.clearTileCache()
            }
        }
    }
    
    @IBAction func onStartButtonSelected(_ sender: Any) {
//        self.imageSource?.setCenterCoordinate(coord: gpsGenerator.startLocation)
        stopWatch.reset()
//        gpsGenerator.step()
        gpsGenerator.start()
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
        let tilePt = MBUtils.createInfoWindowContent(latLng: gpsGenerator.startLocation, zoom: zoom)
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
//        debugPrint("\(#function) - bearing is: \(position.bearing)")
        if self.useGoogleTiles == false {
            let nwPt = gMapView.projection.point(for: self.boundaryQuad.northWest)
            let sePt = gMapView.projection.point(for: boundaryQuad.southEast)
            
            let frameRect = CGRect(origin: nwPt, size: CGSize(width: abs(sePt.x - nwPt.x), height: abs(sePt.y - nwPt.y)))
            if self.fieldView == nil {
                self.fieldView = PlotDrawingView(frame: frameRect, imageServer: self.imageSource!)
                self.gMapView.addSubview(self.fieldView!)
                cheaterView.frame = frameRect
            }
            self.fieldView?.transform = CGAffineTransform(rotationAngle: CGFloat(radians(degrees: 360-position.bearing)))
            self.fieldView?.frame = frameRect
        }

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
        self.currentZoom = CGFloat(floor(position.zoom))
    }
}

extension GoogleMapsViewController {
    
    func renderGeoJSON(withUrl url : URL) {
        
        let geoJsonParser = GMUGeoJSONParser(url: url)
        geoJsonParser.parse()
        
        let style = GMUStyle(styleID: "", stroke: UIColor.blue, fill: UIColor.white.withAlphaComponent(0.1), width: 1, scale: 1, heading: 1, anchor: CGPoint.zero, iconUrl: nil, title: nil, hasFill: true, hasStroke: false)
        let renderer = GMUGeometryRenderer(map: gMapView, geometries: geoJsonParser.features)
        geoJsonParser.features.first?.style = style
        renderer.render()
    }
    
    func getCoordRect(forZoomLevel zoom : UInt) -> CGRect {
        guard let field = geoField else {
            return CGRect.zero
        }
        
        let topLeft = MBUtils.createInfoWindowContent(latLng: field.northWest, zoom: zoom)
        let topRight = MBUtils.createInfoWindowContent(latLng: field.northEast, zoom: zoom)
        let bottomRight = MBUtils.createInfoWindowContent(latLng: field.southEast, zoom: zoom)
        //    let bottomLeft = createInfoWindowContent(latLng: field.bottomLeft, zoom: 16)
//        debugPrint("Pts are: \(topLeft), \(topRight), \(bottomRight)")
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
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
