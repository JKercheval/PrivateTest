//
//  FieldGpsGenerator.swift
//  Scratch
//
//  Created by Jeremy Kercheval on 11/19/20.
//

import Foundation
import CoreLocation
import GEOSwift
import MQTTClient

let defaultMachineWidth : Double = 120 // feet
let defaultMachineWidthMeters : Double = 27.432
let defaultRowCount : UInt = 54

typealias PlottedRowValues = Array<CGFloat>
struct PlottedRow : Codable {
    var location : CLLocationCoordinate2D?
    var rowInfoArr : PlottedRowValues?
    var rowHeading : Double
    
    enum CodingKeys: String, CodingKey {
        case location
        case rowInfoArr
        case rowHeading = "heading"
    }
    
    init(location : CLLocationCoordinate2D, heading : Double, rows: PlottedRowValues) {
        self.location = location
        self.rowHeading = heading
        self.rowInfoArr = rows
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        location = try values.decode(CLLocationCoordinate2D.self, forKey: .location)
        rowHeading = try values.decode(Double.self, forKey: .rowHeading)
        rowInfoArr = try values.decode(PlottedRowValues.self, forKey: .rowInfoArr)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
//        try container.encode(longitude, forKey: .longitude)
        try container.encode(self.rowHeading, forKey: .rowHeading)
        try container.encode(self.rowInfoArr, forKey: .rowInfoArr)
        
    }

}

class FieldGpsGenerator {
    var timer = Timer()
    private var fieldBoundary : FieldBoundaryCorners!
    fileprivate var session : MQTTSession!
    var currentLocation: CLLocationCoordinate2D = CLLocationCoordinate2D()
    // Default value for the MPH Measurement will be six...
    private var milesPerHourMeasurement = Measurement(value: 6, unit: UnitSpeed.milesPerHour)
    private var currentHeading : Double = 0
    
    init(fieldBoundary : FieldBoundaryCorners, session : MQTTSession) {
        self.fieldBoundary = fieldBoundary
        self.currentLocation = fieldBoundary.southWest
        self.session = session
        // Adjust the starting location so that the center point is up a little and to the right of the boundary so
        // that we actually start in the field...
        let centerOffset = Measurement(value: defaultMachineWidth, unit: UnitLength.feet).converted(to: UnitLength.meters).value / 2
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
    
    var currentFieldBoundary : FieldBoundaryCorners {
        get {
            return fieldBoundary
        }
        set {
            self.stop()
            fieldBoundary = newValue
            self.reset()
        }
    }
    
    func getMockRowInfoArray(rowCount : UInt) -> [CGFloat] {
        var rowValues = [CGFloat]()
        for _ in 0..<rowCount {
            rowValues.append(CGFloat.random(in: 0.15...0.25))
        }
        return rowValues
    }
    
    func createMockPlottedRow(coord : CLLocationCoordinate2D, heading : Double, rowCount : UInt = defaultRowCount) -> PlottedRow {
        let plottedRow = PlottedRow(location: coord, heading: heading, rows: getMockRowInfoArray(rowCount: defaultRowCount))
        return plottedRow
    }
    
    func start() {
        debugPrint("\(self):\(#function) - Curent location is: \(currentLocation)")
        let plottedRow = createMockPlottedRow(coord: self.currentLocation, heading: self.currentHeading)
        publishRow(row: plottedRow)
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateNextCoord), userInfo: nil, repeats: true)
    }
    
    func step() {
        updateNextCoord()
    }
    
    func reset() {
        self.stop()
        self.currentHeading = 0
        self.currentLocation = fieldBoundary.southWest
        let centerOffset = Measurement(value: defaultMachineWidth, unit: UnitLength.feet).converted(to: UnitLength.meters).value / 2
        self.currentLocation = self.startLocation.locationWithBearing(bearingRadians: 90, distanceMeters: centerOffset).locationWithBearing(bearingRadians: 0, distanceMeters: 10)
    }
    
    @objc func updateNextCoord() {
//        var heading : Double = 45
        let metersPerSec = milesPerHourMeasurement.converted(to: UnitSpeed.metersPerSecond)
        let nextLoc = self.currentLocation.locationWithBearing(bearingRadians: radians(degrees: currentHeading), distanceMeters: metersPerSec.value/5.0)
        let verDistance = currentLocation.distance(from: CLLocationCoordinate2D(latitude: currentLocation.latitude, longitude: nextLoc.longitude))
        if currentHeading == 0 {
            if verDistance <= Measurement(value: defaultMachineWidth, unit: UnitLength.feet).converted(to: UnitLength.meters).value {
                
            }
        }
        else {
            // is current heading 180 yet?
            if currentHeading < 180.0 {
//                currentHeading += 
            }
        }
        
        let plottedRow = createMockPlottedRow(coord: nextLoc, heading: self.currentHeading)
        currentLocation = nextLoc
        publishRow(row: plottedRow)

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
    
    func publishRow(row : PlottedRow) {
        if let encoded =  try? JSONEncoder().encode(row) {
//            let statusData = "Available".data(using: .utf8)
            self.session?.publishData(encoded, onTopic: "planter/row", retain: false, qos: .atLeastOnce) { error in
                guard error == nil else {
                    assertionFailure("Failed to publish")
                    debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                    return
                }
            }
        }
    }
    
}
