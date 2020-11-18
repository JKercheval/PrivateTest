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

let TileSize : CGFloat = 512.0

class TileRectMap {
    var tileRectDictionary : [UInt : CGRect] = [UInt : CGRect]()
}

class GoogleMapsViewController: UIViewController, GMSMapViewDelegate {

    var geoFeild : GeoJSONField?
    var gMapView : GMSMapView!
    var boundingRect : CGRect = CGRect.zero
    var tileMap : TileRectMap = TileRectMap()
    var currentZoom : Float = 16.0
    var tileLayer : CustomTileLayer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        geoFeild = GeoJSONField(fieldName: "FotF Plot E Boundary")
        guard let feild = geoFeild else {
            return
        }
        // Do any additional setup after loading the view.
        // Create a GMSCameraPosition that tells the map to display the
        // coordinate -33.86,151.20 at zoom level 6.
        let camera = GMSCameraPosition.camera(withLatitude: feild.bottomLeft.latitude, longitude: feild.bottomLeft.longitude, zoom: currentZoom)
        
        gMapView = GMSMapView.map(withFrame: self.view.frame, camera: camera)
        
        gMapView.delegate = self
        gMapView.mapType = .satellite
//        self.view.insertSubview(gMapView, belowSubview: self.TestButton)
        self.view.addSubview(gMapView)
        
        guard let path = Bundle.main.path(forResource: "FotF Plot E Boundary", ofType: "geojson") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        renderGeoJSON(withUrl: url)

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

extension GoogleMapsViewController {
    
    func renderGeoJSON(withUrl url : URL) {
        
        let geoJsonParser = GMUGeoJSONParser(url: url)
        geoJsonParser.parse()
        
        let renderer = GMUGeometryRenderer(map: gMapView, geometries: geoJsonParser.features)
        renderer.render()
    }
    
    func getCoordRect(forZoomLevel zoom : UInt) -> CGRect {
        guard let field = geoFeild else {
            return CGRect.zero
        }
        
        let topLeft = createInfoWindowContent(latLng: field.topLeft, zoom: zoom)
        let topRight = createInfoWindowContent(latLng: field.topRight, zoom: zoom)
        let bottomRight = createInfoWindowContent(latLng: field.bottomRight, zoom: zoom)
        //    let bottomLeft = createInfoWindowContent(latLng: field.bottomLeft, zoom: 16)
        debugPrint("Pts are: \(topLeft), \(topRight), \(bottomRight)")
        return CGRect(x: topLeft.x, y: topLeft.y, width: topRight.x - topLeft.x + 1, height: bottomRight.y - topRight.y + 1)
    }
    
    func createInfoWindowContent(latLng: CLLocationCoordinate2D, zoom: UInt) -> CGPoint {
        let scale = 1 << zoom;
        
        let worldCoordinate = project(latLng: latLng);
        
        let pixelCoordinate = CGPoint(
            x: floor(worldCoordinate.x * CGFloat(scale)),
            y: floor(worldCoordinate.y * CGFloat(scale))
        );
        
        let tileCoordinate = CGPoint(
            x: floor((worldCoordinate.x * CGFloat(scale)) / CGFloat(TileSize)),
            y: floor((worldCoordinate.y * CGFloat(scale)) / CGFloat(TileSize))
        );
        
        return tileCoordinate
        //    return [
        //      "Chicago, IL",
        //      "LatLng: " + latLng,
        //      "Zoom level: " + zoom,
        //      "World Coordinate: " + worldCoordinate,
        //      "Pixel Coordinate: " + pixelCoordinate,
        //      "Tile Coordinate: " + tileCoordinate,
        //    ].join("<br>");
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

class CustomTileLayer: GMSTileLayer {
    var tileDictionary : TileRectMap!
    init(tileDictionary : TileRectMap) {
        self.tileDictionary = tileDictionary
    }
    override func requestTileFor(x: UInt, y: UInt, zoom: UInt, receiver: GMSTileReceiver) {
        let tilePt = CGPoint(x: Int(x), y: Int(y))
        //    debugPrint("Asking for Tile at \(tilePt) for Zoom level: \(zoom)")
        guard let boundary = tileDictionary.tileRectDictionary[zoom] else {
            //      debugPrint("No Tiles for Zoom defined")
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
            return
        }
        guard boundary.contains(tilePt) else {
            //      debugPrint("Tile outside of boundary")
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: nil)
            return
        }
        let key = MBUtils.stringForCaching(withPoint: tilePt, zoomLevel: zoom)
        if let cachedImage = PINCache.shared.object(forKey: key) as? UIImage {
            debugPrint("Using Cached image for \(key)")
            receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: cachedImage)
            return
        }
        
        let image = MBUtils.createFirstImage(size: CGSize(width: TileSize, height: TileSize))
        PINCache.shared.setObject(image, forKey: key)
        receiver.receiveTileWith(x: x, y: y, zoom: zoom, image: image)
        debugPrint("Provided image for \(key)")
        //    debugPrint("We would return a tile here")
    }
}
