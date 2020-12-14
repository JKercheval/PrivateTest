//
//  ViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/7/20.
//

import UIKit
import Mapbox

class MapboxMapViewImplementation: MapViewProtocol {
    
    private var mapView : MGLMapView!
    private var parentView : UIView!
    
    init(mapView : MGLMapView, parent : UIView) {
        self.mapView = mapView
        self.parentView = parent
    }
    func point(for coord: CLLocationCoordinate2D) -> CGPoint {
        return mapView.convert(coord, toPointTo: self.parentView)
    }
    
    func points(forMeters meters: Double, at location: CLLocationCoordinate2D) -> CGFloat {
        let metersPerPoint = mapView.metersPerPoint(atLatitude: location.latitude)
        return CGFloat(meters / metersPerPoint)
    }
}

class ViewController: UIViewController, MGLMapViewDelegate {
    @IBOutlet weak var mapView: UIView!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!

    var geoField : GeoJSONField?
    var mglMapView: MGLMapView!
    var preciseButton: UIButton?
    let locationManager = CLLocationManager()
    var currentYlocation : CGFloat = 10
    var currentZoom : Double = 16.0
    var layerIdentifier : String = ""
    var plottingView : LayerDrawingView?
    var boundaryQuad : FieldBoundaryCorners!
    var mapViewImpl : MapboxMapViewImplementation!
    var imageCanvas : PlottingImageCanvasProtocol!
    let serialQueue = DispatchQueue(label: "com.mapbox.queue.serial")

    
    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.newPlottedRow, object: nil)

        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let field = geoField else {
            return
        }

        mglMapView = MGLMapView(frame: view.bounds, styleURL: MGLStyle.satelliteStreetsStyleURL)
        self.mglMapView.setCenter(field.northWest, zoomLevel: currentZoom, animated: false)
        
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }

        // Do any additional setup after loading the view.
        mglMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mglMapView.delegate = self
        self.view.addSubview(mglMapView)
        self.view.insertSubview(mglMapView, belowSubview: startButton)
        mapViewImpl = MapboxMapViewImplementation(mapView: mglMapView, parent: self.view)

        boundaryQuad = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)
        let machineInfo = MachineInfoProtocolImpl(with: defaultMachineWidthMeters, rowCount: defaultRowCount)
        self.imageCanvas = PlottingImageCanvasImpl(boundary: self.boundaryQuad, machineInfo: machineInfo)

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.plottingManager.disconnect()
    }
    
    @IBAction func onStartButtonSelected(_ sender: Any) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.plottingManager.connect() { success in
            if success {
                self.startButton.backgroundColor = UIColor.green
            }
        }
    }
    
    @IBAction func onStopButtonSelected(_ sender: Any) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.plottingManager.disconnect()
        self.startButton.backgroundColor = UIColor.red
    }
    
    @IBAction func onResetButtonSelected(_ sender: Any) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        appDelegate.plottingManager.reset()
        self.imageCanvas.reset()
        guard let view = self.plottingView else {
            return
        }
        view.layer.setNeedsDisplay(view.layer.bounds)
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        guard let field = geoField else {
            return
        }
        
        guard let centerPt = try? field.fieldEnvelope?.centroid() else {
            return
        }
        
        let nwPt = mapViewImpl.point(for: field.northWest)
        let sePt = mapViewImpl.point(for: field.southEast)

        let frameRect = CGRect(origin: nwPt, size: CGSize(width: abs(sePt.x - nwPt.x), height: abs(sePt.y - nwPt.y)))
        if self.plottingView == nil {
            self.plottingView = LayerDrawingView(frame: frameRect, canvas: self.imageCanvas, mapView: self.mapViewImpl)
            self.mglMapView.addSubview(self.plottingView!)
        }
        self.plottingView?.transform = CGAffineTransform(rotationAngle: CGFloat(radians(degrees: 360-mapView.camera.heading)))
        debugPrint("\(#function) - Frame is: \(frameRect)")
        self.plottingView?.frame = frameRect
        
        let centerLoc = CLLocationCoordinate2D(latitude: centerPt.y, longitude: centerPt.x)
        self.mglMapView.setCenter(centerLoc, zoomLevel: currentZoom, animated: false)

        guard let jsonData = self.geoField?.data else {
            debugPrint("\(self):\(#function) - No valid GeoJSON feild found")
            return
        }
        drawPolyline(geoJson: jsonData)
    }
    
    func mapView(_ mapView: MGLMapView, didChangeLocationManagerAuthorization manager: MGLLocationManager) {
        debugPrint("\(#function)")
        guard let accuracySetting = manager.accuracyAuthorization?() else {
            debugPrint("\(#function) - failed to get accuracy")
            return
        }
        if accuracySetting == .reducedAccuracy {
            addPreciseButton()
        } else {
            removePreciseButton()
        }
    }
    
    @objc func ondidUpdateLocation(_ notification:Notification) {
//        guard let plottedRow = notification.userInfo?[userInfoPlottedRowKey] as? PlottedRowInfoProtocol else {
//            return
//        }
//        serialQueue.async { [weak self] in
//            guard let strongSelf = self else {
//                return
//            }
////            let _ = strongSelf.imageSource?.drawRow(with: plottedRow, zoom: UInt(strongSelf.currentZoom))
//        }
    }
    
    func addQuadToShapeLayer(withMap mapView : MGLMapView, originalCoordinate: CLLocationCoordinate2D, coordinates : [CLLocationCoordinate2D]) {
        struct StaticVars {
            static var counter = 0
        }
        StaticVars.counter += coordinates.count
        debugPrint("Current count of CLLocationCoordinate2D is: \(StaticVars.counter)")
        
        // get the style object from the mapview.
        guard let style = mapView.style else { return }
        // ensure there are items in the array - at some point we might validate the number?
        guard coordinates.count > 0 else { return }
        // get the first location so we can use that as an identifier
        guard let first = coordinates.first else { return }
        
        let polygon = MGLPolygonFeature(coordinates: coordinates, count: UInt(coordinates.count))
        layerIdentifier = "\(first.latitude)_\(first.longitude)"
        let source = MGLShapeSource(identifier: layerIdentifier, shape: polygon)
        style.addSource(source)
        
        //    let randomCGFloat = CGFloat.random(in: 0.1...1)
        
        let fill = MGLFillStyleLayer(identifier: layerIdentifier, source: source)
        fill.fillColor = NSExpression(forConstantValue: UIColor.red)
        fill.fillOpacity = NSExpression(forConstantValue: 0.3)
        
        style.addLayer(fill)
        
    }
    
    func setPlottingViewFrame(withHeading heading : Double) {
        if let view = self.plottingView, let field = geoField {
            let nwPt = mapViewImpl.point(for: field.northWest)
            
            let meters = boundaryQuad.northWest.distance(from: boundaryQuad.northEast)
            let distance = mapViewImpl.points(forMeters: meters, at: boundaryQuad.northWest)
            
            let frameRect = CGRect(origin: nwPt, size: CGSize(width: distance, height: distance * view.aspectRatio))
            view.transform = CGAffineTransform.identity
            view.frame = frameRect
            view.transform = CGAffineTransform(rotationAngle: CGFloat(radians(degrees: heading)))
        }
    }
    
    func mapView(_ mapView: MGLMapView, regionIsChangingWith reason: MGLCameraChangeReason) {
        self.setPlottingViewFrame(withHeading: 360-mapView.camera.heading)
    }

    func mapView(_ mapView: MGLMapView, regionDidChangeWith reason: MGLCameraChangeReason, animated: Bool) {
        self.setPlottingViewFrame(withHeading: 360-mapView.camera.heading)
    }
    
    func createFirstImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            // Create the image with a transparent background
            ctx.cgContext.setFillColor(UIColor.red.cgColor)
            ctx.cgContext.setAlpha(0.5)
            ctx.cgContext.fill(CGRect(origin: CGPoint(x: 0, y: 0), size: size))
        }
        return img
    }

    func addPreciseButton() {
        debugPrint("\(#function)")
        let preciseButton = UIButton(frame: CGRect.zero)
        preciseButton.setTitle("Turn Precise On", for: .normal)
        preciseButton.backgroundColor = .gray
        
        preciseButton.addTarget(self, action: #selector(requestTemporaryAuth), for: .touchDown)
        self.view.addSubview(preciseButton)
        self.preciseButton = preciseButton
        
        // constraints
        preciseButton.translatesAutoresizingMaskIntoConstraints = false
        preciseButton.widthAnchor.constraint(equalToConstant: 150.0).isActive = true
        preciseButton.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
        preciseButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 100.0).isActive = true
        preciseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    }
    
    @available(iOS 14, *)
    @objc private func requestTemporaryAuth() {
//        debugPrint("\(#function)")
        guard let mView = self.mglMapView else { return }
        
        let purposeKey = "MGLAccuracyAuthorizationDescription"
        mView.locationManager.requestTemporaryFullAccuracyAuthorization!(withPurposeKey: purposeKey)
    }
    
    private func removePreciseButton() {
        guard let button = self.preciseButton else { return }
        button.removeFromSuperview()
        self.preciseButton = nil
    }
    
    func drawPolyline(geoJson: Data) {
        guard let mapView = self.mglMapView else {
            return
        }
        // Add our GeoJSON data to the map as an MGLGeoJSONSource.
        // We can then reference this data from an MGLStyleLayer.
        
        // MGLMapView.style is optional, so you must guard against it not being set.
        guard let style = mapView.style else { return }
        guard let shapeFromGeoJSON = try? MGLShape(data: geoJson, encoding: String.Encoding.utf8.rawValue) else {
            fatalError("Could not generate MGLShape")
        }
        let source = MGLShapeSource(identifier: "polyline", shape: shapeFromGeoJSON, options: nil)
        style.addSource(source)
        
        // Create new layer for the line.
        let layer = MGLLineStyleLayer(identifier: "polyline", source: source)
        
        // Set the line join and cap to a rounded end.
        layer.lineJoin = NSExpression(forConstantValue: "round")
        layer.lineCap = NSExpression(forConstantValue: "round")
        
        // Set the line color to a constant blue color.
        layer.lineColor = NSExpression(forConstantValue: UIColor(red: 59/255, green: 178/255, blue: 208/255, alpha: 1))
        layer.lineWidth = NSExpression(forConstantValue: 2)
        
        style.addLayer(layer)
    }
}

extension ViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
//        debugPrint("\(#function)")
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }

}
