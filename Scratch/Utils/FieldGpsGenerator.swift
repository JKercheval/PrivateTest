//
//  FieldGpsGenerator.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/19/20.
//

import Foundation
import CoreLocation
import GEOSwift

let defaultMachineWidht : Double = 120

class FieldGpsGenerator {
    var timer = Timer()
    private var fieldBoundary : FieldBoundaryCorners!
    private var currentLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    // Default value for the MPH Measurement will be six...
    private var milesPerHourMeasurement = Measurement(value: 6, unit: UnitSpeed.milesPerHour)
    private var currentHeading : Double = 0
    
    init(fieldBoundary : FieldBoundaryCorners) {
        self.fieldBoundary = fieldBoundary
        // Adjust the starting location so that the center point is up a little and to the right of the boundary so
        // that we actually start in the field...
        let centerOffset = Measurement(value: defaultMachineWidht, unit: UnitLength.feet).converted(to: UnitLength.meters).value / 2
        self.currentLocation = self.startLocation.locationWithBearing(bearingRadians: 90, distanceMeters: centerOffset).locationWithBearing(bearingRadians: 0, distanceMeters: 10)
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
            return fieldBoundary.southWest
        }
    }
    
    private var endLocation : CLLocationCoordinate2D {
        get {
            return fieldBoundary.northWest
        }
    }
    
    func start() {
        debugPrint("\(self):\(#function) - Curent location is: \(currentLocation)")
        NotificationCenter.default.post(name: NSNotification.Name.didUpdateLocation, object: self.currentLocation)
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
            if verDistance <= Measurement(value: defaultMachineWidht, unit: UnitLength.feet).converted(to: UnitLength.meters).value {
                
            }
        }
        else {
            // is current heading 180 yet?
            if currentHeading < 180.0 {
//                currentHeading += 
            }
        }
        // calculateCoordinateFrom(self.currentLocation, 0, 1)
        let plottedRow = PlottedRow(plotCoord: nextLoc, heading: currentHeading, rowValues: [])
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
