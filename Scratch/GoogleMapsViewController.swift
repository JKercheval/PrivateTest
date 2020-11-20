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
    var drawingManager : DrawingManager!
    
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
        // coordinate and zoom that we want
        let camera = GMSCameraPosition.camera(withLatitude: feild.bottomLeft.latitude, longitude: feild.bottomLeft.longitude, zoom: currentZoom)
        
        gMapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        
        gMapView.delegate = self
        gMapView.mapType = .satellite
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
    
    func getZoomLevel(map : GMSMapView) -> UInt {
        let region = map.projection.visibleRegion()
        let longitudeDelta = region.farRight.longitude - region.farLeft.longitude
        let zoom = log2(360.0 * Double(map.bounds.size.width) / longitudeDelta) - 8
        return UInt(zoom)
//    MKMapView *map = (MKMapView *)self.mapView;
//    CLLocationDegrees longitudeDelta = map.region.span.longitudeDelta;
//    CGFloat mapWidthInPixels = map.bounds.size.width;
//    double zoomScale = longitudeDelta * 85445659.44705395 * M_PI / (180.0 * mapWidthInPixels);
//    double zoomer = 20 - log2(zoomScale);
//    if ( zoomer < 0 ) zoomer = 0;
//
//    return (NSInteger)zoomer;
    }
    
    /*
     Notes:
        Maintain ZBuffer of space for draw coordinates, when required hand off the section
     */
    @objc func ondidUpdateLocation(_ notification:Notification) {
        let coord = notification.object as! CLLocationCoordinate2D
        self.drawingManager.zoom = UInt(self.currentZoom)
        if self.drawingManager.drawRow(at: coord) == true {
            self.tileLayer.clearTileCache()
        }
    }
    
    @IBAction func onStartButtonSelected(_ sender: Any) {
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
        debugPrint("\(#function) Zoom level is: \(position.zoom)")
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
        // HACK HACK
        let remainder = position.zoom.fraction
        if remainder > 0.4 {
            self.currentZoom = ceil(position.zoom)
        }
        else {
            self.currentZoom = floor(position.zoom)
        }
        debugPrint("\(#function) Current zoom level set to: \(self.currentZoom)")
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
