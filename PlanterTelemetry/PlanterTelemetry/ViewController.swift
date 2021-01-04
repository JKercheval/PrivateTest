//
//  ViewController.swift
//  PlanterTelemetry
//
//  Created by Jeremy Kercheval on 12/10/20.
//

// Set this to the IP Address of the machine running MQTT
// Can be "localhost" if running on same machine
let serverAddress = "192.168.86.29"

import Cocoa
import MQTTClient
import CoreLocation
import GEOSwift
import MapKit

class ViewController: NSViewController {
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var textField: NSTextField!
    @IBOutlet weak var stepper: NSStepper!
    @IBOutlet weak var comboBox: NSComboBox!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var masterCheckbox: NSButton!
    
    var gpsGenerator : FieldGpsGenerator!
    var geoField : GeoJSONField?
    let defaultHost = "localhost"
    private var transport = MQTTCFSocketTransport()
    fileprivate var session : MQTTSession! = MQTTSession()
    override func viewDidLoad() {
        super.viewDidLoad()
        MQTTLog.setLogLevel(.info)

        // Do any additional setup after loading the view.
        self.session?.delegate = self
        self.transport.host = serverAddress
        self.transport.port = 1883
        session.userName = "tester"
        session.password = "tester"
        session?.transport = transport
        textField.stringValue = "\(stepper.integerValue)"
        comboBox.removeAllItems()
        self.mapView.mapType = .hybrid
        self.mapView.delegate = self
        self.mapView.register(MKPinAnnotationView.self, forAnnotationViewWithReuseIdentifier: "pin")
        
        let files = Bundle.main.paths(forResourcesOfType: "geojson", inDirectory: nil, forLocalization: nil)
        debugPrint("Files are: \(files)")
        for file in files {
            let fileName = ((file as NSString).deletingPathExtension as NSString).lastPathComponent
            comboBox.addItem(withObjectValue: fileName)
        }
        comboBox.selectItem(at: 0)
        comboBox.delegate = self
        
        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let field = geoField else {
            return
        }
        let boundaryQuad = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)

        let region = MKCoordinateRegion(center: field.northWest, latitudinalMeters: 1500, longitudinalMeters: 1500)
        mapView.setRegion(region, animated: true)
        self.mapView.setCenter(field.northWest, animated: true)

        gpsGenerator = FieldGpsGenerator(fieldBoundary: boundaryQuad, session: session)
        gpsGenerator.speed = 6.0 // mph

        session?.connect() { error in
            guard let someError = error else {
                debugPrint("\(#function) No Error")
                return
            }
            debugPrint("\(#function) connection completed with status \(someError.localizedDescription)")
        }
            
//        self.addFieldMarkers(fieldBoundary: boundaryQuad)
        self.addFieldPolygon(fieldBoundary: boundaryQuad)
    }
    
    func addFieldMarkers(fieldBoundary : FieldBoundaryCorners) {
        var corners = [MKPointAnnotation]()
        
        var annotation = MKPointAnnotation()
        annotation.coordinate = fieldBoundary.northWest
        corners.append(annotation)
        annotation = MKPointAnnotation()
        annotation.coordinate = fieldBoundary.northEast
        corners.append(annotation)
        annotation = MKPointAnnotation()
        annotation.coordinate = fieldBoundary.southEast
        corners.append(annotation)
        annotation = MKPointAnnotation()
        annotation.coordinate = fieldBoundary.southWest
        corners.append(annotation)

        self.mapView.addAnnotations(corners)
    }
    
    func addFieldPolygon(fieldBoundary : FieldBoundaryCorners) {
        let points = [fieldBoundary.northWest, fieldBoundary.northEast, fieldBoundary.southEast, fieldBoundary.southWest]
        let polyline = MKPolygon(coordinates: points, count: points.count)
        self.mapView.addOverlay(polyline)
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func masterSelected(_ sender: Any) {
        debugPrint("Master Selected - checked is \(masterCheckbox.state)")
        gpsGenerator.masterStateOn = masterCheckbox.state == .on
    }
    
    @IBAction func startButtonPressed(_ sender: Any) {
        self.comboBox.isEnabled = false
        gpsGenerator.start()
    }
    
    @IBAction func onStopButtonSelected(_ sender: Any) {
        gpsGenerator.stop()
        self.comboBox.isEnabled = true
    }
    
    @IBAction func onStepperChange(_ sender: NSStepper) {
//        let myLocalCount = sender.integerValue
        textField.stringValue = "\(sender.integerValue)"
        gpsGenerator.heading = sender.doubleValue
    }
}
extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        guard !annotation.isKind(of: MKUserLocation.self) else {
            // Make a fast exit if the annotation is the `MKUserLocation`, as it's not an annotation view we wish to customize.
            return nil
        }
        
        let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: "pin", for: annotation)
        return pinView
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolygonRenderer(overlay: overlay)
        polylineRenderer.strokeColor = NSColor.blue
        polylineRenderer.fillColor = NSColor.red.withAlphaComponent(0.1)
        polylineRenderer.lineWidth = 1
        return polylineRenderer
    }
}
extension ViewController : NSComboBoxDelegate {
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        guard let filename = self.comboBox.itemObjectValue(at: self.comboBox.indexOfSelectedItem) as? String else {
            return
        }
        debugPrint("\(#function) - value changed to: \(filename)")
        geoField = GeoJSONField(fieldName: filename)
        guard let field = geoField else {
            return
        }
        let newBoundary = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)

        gpsGenerator.currentFieldBoundary = newBoundary
        let pins = self.mapView.annotations
        self.mapView.removeAnnotations(pins)
        let polygon = self.mapView.overlays
        self.mapView.removeOverlays(polygon)
//        self.addFieldMarkers(fieldBoundary: newBoundary)
        self.addFieldPolygon(fieldBoundary: newBoundary)
    }
}

extension ViewController : MQTTSessionDelegate {
    
    func connected(_ session: MQTTSession!) {
        debugPrint("\(#function) Connected")
        
        session?.subscribe(toTopic: "topic/state", at: .atLeastOnce, subscribeHandler: { (error, array) in
            guard error == nil else {
                assertionFailure("Failed to subscribe")
                debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                return
            }
            debugPrint("\(#function) \(array!)")
        })
        
    }
    
    func connectionClosed(_ session: MQTTSession!) {
        debugPrint("\(#function) Connected")
    }
    
    func connectionRefused(_ session: MQTTSession!, error: Error!) {
        debugPrint("\(#function) Refused")
    }
    
    func connectionError(_ session: MQTTSession!, error: Error!) {
        debugPrint("\(#function) Error: \(error!.localizedDescription)")
    }
    
    func newMessage(_ session: MQTTSession!, data: Data!, onTopic topic: String!, qos: MQTTQosLevel, retained: Bool, mid: UInt32) {
        guard let messageData = data, let messageTopic = topic else {
            return
        }
        let str = String(decoding: messageData, as: UTF8.self)
        debugPrint("\(#function) \(messageTopic):\(str)")
    }
}
