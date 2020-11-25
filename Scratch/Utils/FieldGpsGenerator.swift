//
//  FieldGpsGenerator.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/19/20.
//

import Foundation
import CoreLocation
import GEOSwift


class FieldGpsGenerator {
    var timer = Timer()
    private var fieldBoundary : Envelope = Envelope(minX: 0, maxX: 0, minY: 0, maxY: 0)
    private var currentLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    
    init(fieldBoundary : Envelope) {
        self.fieldBoundary = fieldBoundary
        self.currentLocation = self.startLocation
    }
    
    var startLocation : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: fieldBoundary.minY, longitude: fieldBoundary.minX)
        }
    }
    
    private var endLocation : CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: fieldBoundary.maxY, longitude: fieldBoundary.minX)
        }
    }
    
    func start() {
        debugPrint("\(self):\(#function) - Curent location is: \(currentLocation)")
        let nextLoc = self.startLocation.locationWithBearing(bearingRadians: radians(degrees: 0), distanceMeters: 1)
        //calculateCoordinateFrom(self.startLocation, 0, 1)
        debugPrint("\(self):\(#function) - Next location is: \(nextLoc)")
        NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: nextLoc)
        currentLocation = nextLoc
        debugPrint("\(self):\(#function) - new curent location is: \(currentLocation)")
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateNextCoord), userInfo: nil, repeats: true)
    }
    
    func step() {
        updateNextCoord()
    }
    
    @objc func updateNextCoord() {
        let nextLoc = self.currentLocation.locationWithBearing(bearingRadians: radians(degrees: 0), distanceMeters: 1)
        // calculateCoordinateFrom(self.currentLocation, 0, 1)
        NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: nextLoc)
        currentLocation = nextLoc
//        debugPrint("\(#function) - new curent location is: \(currentLocation)")
        if currentLocation.latitude > endLocation.latitude {
            stop()
        }
    }
    
    func stop() {
        debugPrint("\(#function) - Stopped timer")
        timer.invalidate()
        timer = Timer()
    }
    
}
