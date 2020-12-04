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
    
    func points(for meters: Double, at location: CLLocationCoordinate2D) -> CGFloat {
        return mapView.projection.points(forMeters: meters, at: location)
    }

}

class GoogleMapsViewController: UIViewController, GMSMapViewDelegate {
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var headingTextField: UITextField!
    @IBOutlet weak var stepperControl: UIStepper!
    
    // Set this to 'true' to see our Google Tile implementation at work.
    var useGoogleTiles : Bool = false
    
    var geoField : GeoJSONField?
    var gMapView : GMSMapView!
    var internalMapView : GMSMapView!

    var currentZoom : CGFloat = 16.0
    var tileLayer : CustomTileLayer!
    var gpsGenerator : FieldGpsGenerator!
    var drawingManager : DrawingManager!
    var imageSource : GoogleTileImageService?
    let serialQueue = DispatchQueue(label: "com.queue.serial")
    var stopWatch = Stopwatch()

    var fieldView : LayerDrawingView?
    var cheaterView : UIView!
    var boundaryQuad : FieldBoundaryCorners!
    var farmBoundary : FieldBoundaryCorners!
    var mapViewImpl : GoogleMapViewImplementation!
    var imageCanvas : PlottingImageCanvasProtocol!
    
    
    fileprivate func initializeMapTileLayer(imageServer : GoogleTileImageService?) {
        guard let server = imageServer else {
            return
        }
        tileLayer = CustomTileLayer(imageServer: server)
        tileLayer.tileSize = Int(TileSize)
        tileLayer.opacity = 0.3
        tileLayer.fadeIn = false
        tileLayer.map = gMapView
    }
    
    func initializeFarmBoundary() -> FieldBoundaryCorners {
        var farmBoundary : GMSCoordinateBounds = GMSCoordinateBounds()
        let plotE = GeoJSONField(fieldName: "FotF Plot E Boundary")
        let plotA = GeoJSONField(fieldName: "FotF Plot A Boundary")
        let plotD = GeoJSONField(fieldName: "FotF Plot D Boundary")
        let plotC = GeoJSONField(fieldName: "FotF Plot C Boundary")
        let plotF = GeoJSONField(fieldName: "FotF Plot F Boundary")
        let plotB = GeoJSONField(fieldName: "FotF Plot B Boundary")
        farmBoundary = GMSCoordinateBounds(coordinate: plotA.northWest, coordinate: plotA.southEast)
        farmBoundary = farmBoundary.includingBounds(GMSCoordinateBounds(coordinate: plotE.northWest, coordinate: plotE.southEast))
        farmBoundary = farmBoundary.includingBounds(GMSCoordinateBounds(coordinate: plotD.northWest, coordinate: plotD.southEast))
        farmBoundary = farmBoundary.includingBounds(GMSCoordinateBounds(coordinate: plotC.northWest, coordinate: plotC.southEast))
        farmBoundary = farmBoundary.includingBounds(GMSCoordinateBounds(coordinate: plotF.northWest, coordinate: plotF.southEast))
        farmBoundary = farmBoundary.includingBounds(GMSCoordinateBounds(coordinate: plotB.northWest, coordinate: plotB.southEast))
        
        let northWest = CLLocationCoordinate2D(latitude: farmBoundary.northEast.latitude, longitude: farmBoundary.southWest.longitude)
        let southEast = CLLocationCoordinate2D(latitude: farmBoundary.southWest.latitude, longitude: farmBoundary.northEast.longitude)
        let corners = FieldBoundaryCorners(withCoordinates: northWest, southEast: southEast, northEast: farmBoundary.northEast, southWest: farmBoundary.southWest)
        return corners
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        PINMemoryCache.shared.removeAllObjects()
        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.didUpdateLocation, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        cheaterView = UIView(frame: CGRect.zero)
        
        // Do any additional setup after loading the view.
        self.farmBoundary = initializeFarmBoundary()
        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let field = geoField else {
            return
        }
        
        // Do any additional setup after loading the view.
        // Create a GMSCameraPosition that tells the map to display the
        // coordinate and zoom that we want
        let camera = GMSCameraPosition.camera(withLatitude: field.southWest.latitude, longitude: field.southWest.longitude, zoom: Float(currentZoom))
        gMapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        
        // This is currently used to cheaat on map tile locations since I am currently using the mapview to find the coordinates
        // of the tile corners for offsets in the Tile generator.
        let internalCamera = GMSCameraPosition.camera(withLatitude: field.northWest.latitude, longitude: field.northWest.longitude, zoom: Float(20))
        self.internalMapView = GMSMapView.map(withFrame: UIScreen.screens.first!.bounds, camera: internalCamera)

        gMapView.delegate = self
        gMapView.settings.allowScrollGesturesDuringRotateOrZoom = false
//        gMapView.settings.rotateGestures = false
        gMapView.mapType = .satellite
        gMapView.setMinZoom(10, maxZoom: 22)

//        mapViewImpl = GoogleMapViewImplementation(mapView: internalMapView)
        mapViewImpl = GoogleMapViewImplementation(mapView: gMapView)
        
        self.view.insertSubview(gMapView, belowSubview: self.startButton)
        self.drawingManager = DrawingManager(with: CGFloat(54.0 * (3.0/inchesPerMeter)), rowCount: 54, mapView: gMapView)
        
        renderGeoJSON(for: "FotF Plot E Boundary")
        renderGeoJSON(for: "FotF Plot A Boundary")
        renderGeoJSON(for: "FotF Plot B Boundary")
        renderGeoJSON(for: "FotF Plot C Boundary")
        renderGeoJSON(for: "FotF Plot D Boundary")
        renderGeoJSON(for: "FotF Plot F Boundary")


        let boundsMaxZoom = getCoordRect(forZoomLevel: UInt(20))
        boundaryQuad = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)
        self.imageCanvas = PlottingImageCanvasImpl(boundary: boundaryQuad, machineInfo: MachineInfoProtocolImpl(with: 27.432, rowCount: 54))
        imageSource = GoogleTileImageService(with: boundsMaxZoom, boundQuad: boundaryQuad, canvas: self.imageCanvas, mapView: mapViewImpl)

        if self.useGoogleTiles {
            initializeMapTileLayer(imageServer: imageSource)
        }
        
        gpsGenerator = FieldGpsGenerator(fieldBoundary: boundaryQuad)
        gpsGenerator.speed = 6.0 // mph
        self.headingTextField.text = "\(gpsGenerator.heading)"
//        let nwMarker = GMSMarker(position: farmBoundary.northWest)
//        let seMarker = GMSMarker(position: farmBoundary.southEast)
//        let neMarker = GMSMarker(position: farmBoundary.northEast)
//        let swMarker = GMSMarker(position: farmBoundary.southWest)
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

    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
//        debugPrint("\(#function) - bearing is: \(position.bearing)")
        if self.useGoogleTiles == false {
            let nwPt = gMapView.projection.point(for: boundaryQuad.northWest)
            let sePt = gMapView.projection.point(for: boundaryQuad.southEast)
            
            let frameRect = CGRect(origin: nwPt, size: CGSize(width: abs(sePt.x - nwPt.x), height: abs(sePt.y - nwPt.y)))
            if self.fieldView == nil {
                self.fieldView = LayerDrawingView(frame: frameRect, canvas: self.imageCanvas, mapView: self.mapViewImpl)
                self.gMapView.addSubview(self.fieldView!)
                cheaterView.frame = frameRect
            }
            self.fieldView?.transform = CGAffineTransform(rotationAngle: CGFloat(radians(degrees: 360-position.bearing)))
            self.fieldView?.frame = frameRect
        }

        self.currentZoom = CGFloat(floor(position.zoom))
    }
}

extension GoogleMapsViewController {
    
    func renderGeoJSON(for jsonFile : String) {
        guard let path = Bundle.main.path(forResource: jsonFile, ofType: "geojson") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        let geoJsonParser = GMUGeoJSONParser(url: url)
        geoJsonParser.parse()
        
        let style = GMUStyle(styleID: "", stroke: UIColor.blue, fill: UIColor.white.withAlphaComponent(0.1), width: 1, scale: 1, heading: 1, anchor: CGPoint.zero, iconUrl: nil, title: nil, hasFill: true, hasStroke: true)
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
