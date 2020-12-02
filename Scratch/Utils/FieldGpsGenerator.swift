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
    private var milesPerHourMeasurement = Measurement(value: 1, unit: UnitSpeed.milesPerHour)
    private var currentHeading : Double = 0
    
    init(fieldBoundary : Envelope) {
        self.fieldBoundary = fieldBoundary
        self.currentLocation = self.startLocation
    }
    
    var speed : Double {
        get {
            return milesPerHourMeasurement.value
        }
        set {
            milesPerHourMeasurement.value = newValue
        }
    }
    
    var heading : Double {
        get {
            return currentHeading
        }
        set {
            currentHeading = newValue
        }
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
        let nextLoc = self.startLocation.locationWithBearing(bearingRadians: radians(degrees: currentHeading), distanceMeters: 1)
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
//        var heading : Double = 45
        let metersPerSec = milesPerHourMeasurement.converted(to: UnitSpeed.metersPerSecond)
        let nextLoc = self.currentLocation.locationWithBearing(bearingRadians: radians(degrees: currentHeading), distanceMeters: metersPerSec.value/5.0)
        let verDistance = currentLocation.distance(from: CLLocationCoordinate2D(latitude: currentLocation.latitude, longitude: nextLoc.longitude))
        if currentHeading == 0 {
            if verDistance <= Measurement(value: 120, unit: UnitLength.feet).converted(to: UnitLength.meters).value {
                
            }
        }
        else {
            // is current heading 180 yet?
            if currentHeading < 180.0 {
//                currentHeading += 
            }
        }
        // calculateCoordinateFrom(self.currentLocation, 0, 1)
        let plottedRow = PlottedRow(plotCoord: nextLoc, rowValues: [])
        plottedRow.heading = currentHeading
        NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: self, userInfo: ["plottedRow" : plottedRow])
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
