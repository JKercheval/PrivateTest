//
//  MapkitViewController.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/30/20.
//

import UIKit
import MapKit

class MapkitViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var plottingRenderer : PlottingMapOverlayRenderer?
    var geoField : GeoJSONField?
    var imageCanvas : PlottingImageCanvasProtocol!
    var fieldBoundary : FieldBoundaryCorners!
    var plottingOverlay : PlottingMapOverlay!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.mapView.mapType = .hybrid
        
        geoField = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let field = geoField else {
            return
        }
        fieldBoundary = FieldBoundaryCorners(withCoordinates: field.northWest, southEast: field.southEast, northEast: field.northEast, southWest: field.southWest)
        let machineInfo = MachineInfoProtocolImpl(with: defaultMachineWidthMeters, rowCount: defaultRowCount)
        self.imageCanvas = PlottingImageCanvasImpl(boundary: self.fieldBoundary, machineInfo: machineInfo)
        self.plottingOverlay = PlottingMapOverlay(with: fieldBoundary)
        self.mapView.delegate = self
        self.mapView.addOverlay(self.plottingOverlay)
        
        let region = MKCoordinateRegion(center: field.northWest, latitudinalMeters: 100, longitudinalMeters: 1500)
//        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 41.408563, longitude: -88.857618), span: span)
        mapView.setRegion(region, animated: true)
        self.mapView.setCenter(field.northEast, animated: true)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MapkitViewController {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        debugPrint("\(self):\(#function)")
        if self.plottingRenderer == nil {
            self.plottingRenderer = PlottingMapOverlayRenderer(with: self.imageCanvas, overlay: overlay)
        }
        return self.plottingRenderer!
    }
}


class PlottingMapOverlay: NSObject, MKOverlay {
    var coordinate: CLLocationCoordinate2D
    
    let fieldBoundaries: FieldBoundaryCorners
    let boundingMapRect: MKMapRect
    
    init(with bounds : FieldBoundaryCorners) {
        self.coordinate = bounds.southWest
        fieldBoundaries = bounds
        let nwPoint = MKMapPoint(fieldBoundaries.northWest)
        let sePoint = MKMapPoint(fieldBoundaries.southEast)
        
        boundingMapRect = MKMapRect(x: nwPoint.x, y: sePoint.y, width: sePoint.x - nwPoint.x, height: sePoint.y - nwPoint.y)
        super.init()
        debugPrint("\(self):\(#function)")
    }
}


class PlottingMapOverlayRenderer: MKOverlayRenderer {
    let imageCanvas : PlottingImageCanvasProtocol
    
    init(with canvas: PlottingImageCanvasProtocol, overlay : MKOverlay) {
        imageCanvas = canvas
        super.init(overlay: overlay)
        debugPrint("\(self):\(#function)")
    }
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        debugPrint("\(#function) MKMapRect: \(mapRect), MKZoomScale: \(zoomScale)")
    }
}
