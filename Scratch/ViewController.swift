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
    @IBOutlet weak var imageView: UIImageView!
    var mglMapView: MGLMapView?
    var preciseButton: UIButton?
    let locationManager = CLLocationManager()
    var currentYlocation : CGFloat = 10
    let someIowaFarmLocation : CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 41.698502, longitude: -93.868718)

    
    override func viewDidLoad() {
        super.viewDidLoad()
        let url = URL(string: "mapbox://styles/mapbox/streets-v11")
        let tmpMglMapView = MGLMapView(frame: view.bounds, styleURL: url)

        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }

        // Do any additional setup after loading the view.
//        MGLLocationManager.requestWhenInUseAuthorization()
        tmpMglMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tmpMglMapView.delegate = self
        tmpMglMapView.showsUserLocation = true
        self.mglMapView = tmpMglMapView
//        self.mapView?.backgroundColor = UIColor.red
        self.mapView.addSubview(tmpMglMapView)
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
    
    func mapView(_ mapView: MGLMapView, regionDidChangeWith reason: MGLCameraChangeReason, animated: Bool) {
        debugPrint("\(#function) - reason is: \(reason)")
    }
    
    @IBAction func onDrawButtonSelected(_ sender: Any) {
        let rowCount : Int = 96
        let height = imageView.frame.height / 2
        let width = imageView.frame.width / 2
        
        var image = imageView.image
        if image == nil {
            image = createFirstImage(size: imageView.frame.size)
        }
        imageView.image = drawRectangleOnImage(image: image!, yLocation: currentYlocation)!
        currentYlocation += 10
//        imageView.image = drawRectangleOnImage(size: CGSize(width: width, height: height))
//        let renderer = UIGraphicsImageRenderer(size: imageView.frame.size)
//        let img = renderer.image { ctx in
//
//            // 4
//            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
//            ctx.cgContext.setLineWidth(0.1)
//
//            // 5
//            let partsWidth = (imageView.frame.width - 20) / CGFloat(rowCount)
//            let startX : CGFloat = 10.0
//            for n in 0..<rowCount {
//                var color = UIColor.yellow.cgColor
//                if n % 2 == 0 {
//                    color = UIColor.red.cgColor
//                }
//                ctx.cgContext.setFillColor(color)
//                let rect = CGRect(x: startX + (partsWidth * CGFloat(n)), y: 10, width: partsWidth, height: partsWidth)
//                ctx.cgContext.fill(rect)
//            }
//        }
//
//        imageView.image = img
    }
    
    func createFirstImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
        }
        return img
    }
    
    func drawRectangleOnImage(image : UIImage, yLocation : CGFloat) -> UIImage? {
        let rowCount : Int = 96

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let img = renderer.image { ctx in
            
            // 4
            ctx.cgContext.setStrokeColor(UIColor.gray.cgColor)
            ctx.cgContext.setLineWidth(0.1)
            
            image.draw(at: CGPoint.zero)
            // 5
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
        
//        imageView.image = img

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
}

extension ViewController : CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let locValue: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        debugPrint("\(#function)")
        print("locations = \(locValue.latitude) \(locValue.longitude)")
        self.mglMapView!.setCenter(someIowaFarmLocation, zoomLevel: 11, animated: false)
    }

}

//extension ViewController : MGLLocationManagerDelegate {
//    func locationManager(_ manager: MGLLocationManager, didUpdate locations: [CLLocation]) {
//        debugPrint("\(#function)")
//    }
//
//    func locationManager(_ manager: MGLLocationManager, didUpdate newHeading: CLHeading) {
//        debugPrint("\(#function)")
//    }
//
//    func locationManagerShouldDisplayHeadingCalibration(_ manager: MGLLocationManager) -> Bool {
//        debugPrint("\(#function)")
//        return true
//    }
//
//    func locationManager(_ manager: MGLLocationManager, didFailWithError error: Error) {
//        debugPrint("\(#function)")
//    }
//
//    func locationManagerDidChangeAuthorization(_ manager: MGLLocationManager) {
//        debugPrint("\(#function)")
//    }
//
//
//
////    var delegate: MGLLocationManagerDelegate? {
////        get {
////            return self
////        }
////        set(delegate) {
////            debugPrint("\(#function)")
////        }
////    }
////
////    var authorizationStatus: CLAuthorizationStatus {
////        return CLAuthorizationStatus.authorizedAlways
////    }
////
////    func requestAlwaysAuthorization() {
////        debugPrint("\(#function)")
////    }
////
////    func requestWhenInUseAuthorization() {
////        debugPrint("\(#function)")
////    }
////
////    func startUpdatingLocation() {
////        debugPrint("\(#function)")
////    }
////
////    func stopUpdatingLocation() {
////        debugPrint("\(#function)")
////    }
////
////    var headingOrientation: CLDeviceOrientation {
////        get {
////            return CLDeviceOrientation.faceUp
////        }
////        set(headingOrientation) {
////            debugPrint("\(#function)")
////        }
////    }
////
////    func startUpdatingHeading() {
////        debugPrint("\(#function)")
////    }
////
////    func stopUpdatingHeading() {
////        debugPrint("\(#function)")
////    }
////
////    func dismissHeadingCalibrationDisplay() {
////        debugPrint("\(#function)")
////    }
////
////
//}
