//
//  GoogleMapsViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/18/20.
//

import UIKit
import GoogleMaps
import GoogleMapsUtils

let TileSize : CGFloat = 512.0

class GoogleMapViewImplementation: MapViewProtocol {

    private var mapView : GMSMapView!

    init(mapView : GMSMapView) {
        self.mapView = mapView
    }
    
    func point(for coord: CLLocationCoordinate2D) -> CGPoint {
        return mapView.projection.point(for: coord)
    }
    
    func points(forMeters meters: Double, at location: CLLocationCoordinate2D) -> CGFloat {
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
    var imageSource : GoogleTileImageService?
    let serialQueue = DispatchQueue(label: "com.queue.serial")
    var stopWatch = Stopwatch()

    var fieldView : LayerDrawingView?
    var fieldBoundary : FieldBoundaryCorners!
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.newPlottedRow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidUpdateRow(_:)), name:.didPlotRowNotification, object: nil)
        
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

        gMapView.delegate = self
        gMapView.settings.allowScrollGesturesDuringRotateOrZoom = false
        gMapView.mapType = .satellite
        gMapView.setMinZoom(Float(10), maxZoom: Float(21))

        // Should we need to use the tiling version for any reason, we need to switch back to using the internal map view
        mapViewImpl = GoogleMapViewImplementation(mapView: gMapView)
        if useGoogleTiles {
            let internalCamera = GMSCameraPosition.camera(withLatitude: field.northWest.latitude, longitude: field.northWest.longitude, zoom: Float(20))
            // this probably will have problems if the user rotates the device, but we are not actively
            // updating the tiling solution.
            self.internalMapView = GMSMapView.map(withFrame: UIScreen.screens.first!.bounds, camera: internalCamera)
            mapViewImpl = GoogleMapViewImplementation(mapView: internalMapView)
        }
        
        self.view.insertSubview(gMapView, belowSubview: self.startButton)
        
        renderGeoJSON(for: "FotF Plot E Boundary")
        renderGeoJSON(for: "FotF Plot A Boundary")
        renderGeoJSON(for: "FotF Plot B Boundary")
        renderGeoJSON(for: "FotF Plot C Boundary")
        renderGeoJSON(for: "FotF Plot D Boundary")
        renderGeoJSON(for: "FotF Plot F Boundary")


        fieldBoundary = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)
        let boundsMaxZoom = MBUtils.getCoordRect(forZoomLevel: UInt(20), northWest: field.northWest, northEast: field.northEast, southEast: field.southEast)
        self.imageCanvas = PlottingImageCanvasImpl(boundary: fieldBoundary, machineInfo: MachineInfoProtocolImpl(with: defaultMachineWidthMeters, rowCount: defaultRowCount))
        imageSource = GoogleTileImageService(with: boundsMaxZoom, boundQuad: fieldBoundary, canvas: self.imageCanvas, mapView: mapViewImpl)

        if self.useGoogleTiles {
            initializeMapTileLayer(imageServer: imageSource)
        }
        
        let nwPt = gMapView.projection.point(for: fieldBoundary.northWest)
        let sePt = gMapView.projection.point(for: fieldBoundary.southEast)
        
        let frameRect = CGRect(origin: nwPt, size: CGSize(width: abs(sePt.x - nwPt.x), height: abs(sePt.y - nwPt.y)))
        self.fieldView = LayerDrawingView(frame: frameRect, canvas: self.imageCanvas, mapView: self.mapViewImpl)
        self.gMapView.addSubview(self.fieldView!)

        gpsGenerator = FieldGpsGenerator(fieldBoundary: fieldBoundary)
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
        
    
    /// Called when we have a new PlottedRow object
    /// - Parameter notification: Notification that contains the PlottedRow info in the userInfo dictionary
    @objc func ondidUpdateLocation(_ notification:Notification) {
        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
            return
        }
        
        serialQueue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            // Passing in Zoom only to help with caching, which is not yet complete and commented out
            // in the TileImageSourceServer...
            let _ = strongSelf.imageCanvas.drawRow(with: plottedRow)
        }
    }
    
    
    /// The user pressed one of the stepper buttons
    /// - Parameter sender: Should be the UIStepper
    @IBAction func onStepperValueChanged(_ sender: Any) {
        guard let stepper = sender as? UIStepper else {
            debugPrint("\(self)\(#function) Failed to get Stepper")
            return
        }

        gpsGenerator.heading = Double(stepper.value)
        self.headingTextField.text = "\(gpsGenerator.heading)"
    }
    
    
    /// Used with the Google Tiles implementation, called after a row was drawn
    /// - Parameter notification: Notification object
    @objc func onDidUpdateRow(_ notification:Notification) {
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
        stopWatch.reset()
//        gpsGenerator.step()
        gpsGenerator.start()
    }

    @IBAction func onStopButtonSelected(_ sender: Any) {
        gpsGenerator.stop()
    }

    func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {

        if self.useGoogleTiles == false {
            guard let view = self.fieldView else {
                return
            }
            // this transform rotates out view around the top left edge, which has been set using an Anchor
            // point in the LayerDrawingView class during init.
            let transform = CGAffineTransform(rotationAngle: CGFloat(radians(degrees: 360-position.bearing)))

            let nwPt = gMapView.projection.point(for: fieldBoundary.northWest)
            // get the distance in pixels using the coordinates so that we always have the correct
            // width for the view.
            let meters = fieldBoundary.northWest.distance(from: fieldBoundary.northEast)
            // This method takes into account the current zoom level which is why we can always use this.
            let distance = gMapView.projection.points(forMeters: meters, at: fieldBoundary.northWest)

            // Set up the frame with the new coordinate for origin, and the size based on x distance and aspect ratio
            let frameRect = CGRect(origin: nwPt, size: CGSize(width: distance, height: distance * view.aspectRatio))
            if self.fieldView != nil {
                self.gMapView.bringSubviewToFront(self.fieldView!)
            }
            // To set the frame of the UIView correctly, we first have to set the transform back to the identity
            self.fieldView?.transform = CGAffineTransform.identity
            self.fieldView?.frame = frameRect
            // now we set the transform to the rotated positiond
            self.fieldView?.transform = transform
        }

        self.currentZoom = CGFloat(floor(position.zoom))
    }
}

extension GoogleMapsViewController {
    
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
}
