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
import GameKit


class FieldGpsGenerator {
    var timer : Timer? = nil
    var masterStateOn = true
    private var testData = [SessionData]()
    private var testDataIndex = 0
    
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
        testData = loadDataFile(name: "data")
    }
    
    private func loadDataFile(name : String) -> [SessionData] {
        let bundle = Bundle.main
        let path = bundle.url(forResource: name, withExtension: "json")//(forResource: "data", ofType: "json")!
        let jsonFileData = try? Data(contentsOf: path!)
        
        let decoder = JSONDecoder()
        if let jsonData = jsonFileData {
            do {
                let testData = try decoder.decode([SessionData].self, from: jsonData)
                return testData
            } catch {
                print(error)
            }
        }
        return [SessionData]()
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

    func getMockRowDataInfoArray(rowCount : UInt) -> [RowDataInfo] {
        var dataInfo = [RowDataInfo]()
        
        let random = GKLinearCongruentialRandomSource()
        
        for index in 0..<rowCount {
            var info = RowVariableInfo()
            let singulation = GKGaussianDistribution(randomSource: random, lowestValue: -16, highestValue: 3)
            info[.singulation] = Float(max(singulation.nextInt(), 0))
            let downforce = GKGaussianDistribution(randomSource: random, lowestValue: 0, highestValue: 600)
            info[.downforce] = Float(max(min(downforce.nextInt(), 300), 175))
            let rideQuality = GKGaussianDistribution(randomSource: random, lowestValue: 50, highestValue: 150)
            info[.rideQuality] = Float(max(min(rideQuality.nextInt(), 100), 70)) / 100
            dataInfo.append(RowDataInfo(rowId: index, rowState: true, rowVariables: info))
        }
        return dataInfo
    }

    func createMockPlottedRow(coord : CLLocationCoordinate2D, heading : Double, rowCount : UInt = defaultRowCount) -> PlottedRowBase {
        let dataInfo = getMockRowDataInfoArray(rowCount: rowCount)
        let plottedRow = PlottedRowBase(location: coord,
                                        heading: heading,
                                        speed: 6.0,
                                        masterRowState: self.masterStateOn,
                                        infoData: dataInfo)
        return plottedRow
    }
    
    func start() {
        guard self.timer == nil else {
            return
        }
        debugPrint("\(self):\(#function) - Curent location is: \(currentLocation)")
        let plottedRow = createMockPlottedRow(coord: self.currentLocation, heading: self.currentHeading)
        publishRow(row: plottedRow)
        timer = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(updateNextCoord), userInfo: nil, repeats: true)
    }
    
    func startSessionData() {
        guard self.timer == nil else {
            return
        }
        testDataIndex = 0
        let data = testData[testDataIndex]
        publishSessionStart(row: data)

        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(sendNextSessionDataPacket), userInfo: nil, repeats: true)
    }
    
    func step() {
        updateNextCoord()
    }
    
    func reset() {
        self.stop()
        testDataIndex = 0
        self.currentHeading = 0
        self.currentLocation = fieldBoundary.southWest
        let centerOffset = Measurement(value: defaultMachineWidth, unit: UnitLength.feet).converted(to: UnitLength.meters).value / 2
        self.currentLocation = self.startLocation.locationWithBearing(bearingRadians: 90, distanceMeters: centerOffset).locationWithBearing(bearingRadians: 0, distanceMeters: 10)
    }
    
    func stop() {
        debugPrint("\(#function) - Stopped timer")
        self.timer?.invalidate()
        self.timer = nil
    }

    @objc func sendNextSessionDataPacket() {
        guard testDataIndex < testData.count else {
            self.stop()
            testDataIndex = 0
            return
        }
        
        let data = testData[testDataIndex]
        testDataIndex += 1
        publishSessionData(row: data)
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
        
    func publishRow(row : PlottedRowBase) {
        if let encoded =  try? JSONEncoder().encode(row) {
            self.session?.publishData(encoded, onTopic: "planter/row", retain: false, qos: .atLeastOnce) { error in
                guard error == nil else {
                    assertionFailure("Failed to publish")
                    debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                    return
                }
            }
        }
    }

    func publishSessionData(row : SessionData) {
        if let encoded =  try? JSONEncoder().encode(row) {
            self.session?.publishData(encoded, onTopic: "planter/sessionData", retain: false, qos: .atLeastOnce) { error in
                guard error == nil else {
                    assertionFailure("Failed to publish")
                    debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                    return
                }
            }
        }
    }

    func publishSessionStart(row : SessionData) {
        if let encoded =  try? JSONEncoder().encode(row) {
            self.session?.publishData(encoded, onTopic: "planter/sessionStart", retain: false, qos: .atLeastOnce) { error in
                guard error == nil else {
                    assertionFailure("Failed to publish")
                    debugPrint("\(#function) Error! - \(error!.localizedDescription)")
                    return
                }
            }
        }
    }

}
