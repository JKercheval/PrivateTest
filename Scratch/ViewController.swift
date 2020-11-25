//
//  ViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/7/20.
//

import UIKit
import Mapbox

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
    var gpsGenerator : FieldGpsGenerator!
    var layerIdentifier : String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(ondidUpdateLocation(_:)), name:.didUpdateLocation, object: nil)
        
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
//        MGLLocationManager.requestWhenInUseAuthorization()
        mglMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mglMapView.delegate = self
//        mglMapView.showsUserLocation = true
        self.view.addSubview(mglMapView)
        self.view.insertSubview(mglMapView, belowSubview: startButton)
        
        guard let envelope = geoField?.fieldEnvelope else {
            return
        }
        gpsGenerator = FieldGpsGenerator(fieldBoundary: envelope)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        self.gpsGenerator.stop()
    }
    
    @IBAction func onStartButtonSelected(_ sender: Any) {
        self.gpsGenerator.start()
    }
    
    @IBAction func onStopButtonSelected(_ sender: Any) {
        self.gpsGenerator.stop()
    }
    
    @IBAction func onResetButtonSelected(_ sender: Any) {
        guard let style = self.mglMapView.style,
              let layer =  self.mglMapView.style?.layer(withIdentifier: self.layerIdentifier),
              let source = self.mglMapView.style?.source(withIdentifier: self.layerIdentifier) else {
            return
        }
        
        // TODO: This does NOT work, haven't spent time to figure out why
        style.removeSource(source)
        style.removeLayer(layer)
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        guard let field = geoField else {
            return
        }
        
        guard let centerPt = try? field.fieldEnvelope?.centroid() else {
            return
        }
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
//        mapView.setCenter(CLLocationCoordinate2D(latitude: 59.31, longitude: 18.06), zoomLevel: 9, animated: false)

        
        if accuracySetting == .reducedAccuracy {
            addPreciseButton()
        } else {
            removePreciseButton()
        }
    }
    
    @objc func ondidUpdateLocation(_ notification:Notification) {
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self, let mapView = strongSelf.mglMapView else {
                return
            }
            let coord = notification.object as! CLLocationCoordinate2D
            let thirtyInchesInMeters = 0.762
            for n in stride(from: 25, through: 1, by: -1) {
                let location = coord.locationWithBearing(bearingRadians: radians(degrees: 270), distanceMeters: (0.762 * 2) * Double(n))
                let quad = location.quadRect(withDistance: thirtyInchesInMeters)
                strongSelf.addQuadToShapeLayer(withMap: mapView, originalCoordinate: coord, coordinates: quad)
            }
            let quad = coord.quadRect(withDistance: thirtyInchesInMeters)
            strongSelf.addQuadToShapeLayer(withMap: mapView, originalCoordinate: coord, coordinates: quad)
            for n in 1...25 {
                let location = coord.locationWithBearing(bearingRadians: radians(degrees: 90), distanceMeters: (0.762 * 2) * Double(n))
                let quad = location.quadRect(withDistance: thirtyInchesInMeters)
                strongSelf.addQuadToShapeLayer(withMap: mapView, originalCoordinate: coord, coordinates: quad)
            }
        }
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
    
    func mapView(_ mapView: MGLMapView, regionDidChangeWith reason: MGLCameraChangeReason, animated: Bool) {
        debugPrint("\(#function) - reason is: \(reason)")
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
    
    func drawRectangleOnImage(image : UIImage, yLocation : CGFloat) -> UIImage? {
        let rowCount : Int = 96

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in
            
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.1)
            
            image.draw(at: CGPoint.zero)
            let partsWidth = (image.size.width - 20) / CGFloat(rowCount)
            let startX : CGFloat = 10.0
            for n in 0..<rowCount {
                var color = UIColor.yellow.cgColor
                if n % 2 == 0 {
                    color = UIColor.red.cgColor
                }
                ctx.cgContext.setFillColor(color)
                let rect = CGRect(x: startX + (partsWidth * CGFloat(n)), y: yLocation, width: partsWidth, height: partsWidth)
                ctx.cgContext.fill(rect)
            }
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
        debugPrint("\(#function)")
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
        // Use `NSExpression` to smoothly adjust the line width from 2pt to 20pt between zoom levels 14 and 18. The `interpolationBase` parameter allows the values to interpolate along an exponential curve.
        //    layer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
        //                                   [14: 2, 18: 20])
        
        // We can also add a second layer that will draw a stroke around the original line.
        //    let casingLayer = MGLLineStyleLayer(identifier: "polyline-case", source: source)
        //    // Copy these attributes from the main line layer.
        //    casingLayer.lineJoin = layer.lineJoin
        //    casingLayer.lineCap = layer.lineCap
        //    // Line gap width represents the space before the outline begins, so should match the main line’s line width exactly.
        //    casingLayer.lineGapWidth = layer.lineWidth
        //    // Stroke color slightly darker than the line color.
        //    casingLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 41/255, green: 145/255, blue: 171/255, alpha: 1))
        //    // Use `NSExpression` to gradually increase the stroke width between zoom levels 14 and 18.
        //    casingLayer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", [14: 1, 18: 4])
        
        //    // Just for fun, let’s add another copy of the line with a dash pattern.
        //    let dashedLayer = MGLLineStyleLayer(identifier: "polyline-dash", source: source)
        //    dashedLayer.lineJoin = layer.lineJoin
        //    dashedLayer.lineCap = layer.lineCap
        //    dashedLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
        //    dashedLayer.lineOpacity = NSExpression(forConstantValue: 0.5)
        //    dashedLayer.lineWidth = layer.lineWidth
        //    // Dash pattern in the format [dash, gap, dash, gap, ...]. You’ll want to adjust these values based on the line cap style.
        //    dashedLayer.lineDashPattern = NSExpression(forConstantValue: [0, 1.5])
        
        style.addLayer(layer)
        //    style.addLayer(dashedLayer)
        //    style.insertLayer(casingLayer, below: layer)
    }
}

extension ViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        debugPrint("\(#function)")
        print("locations = \(locValue.latitude) \(locValue.longitude)")
    }

}
