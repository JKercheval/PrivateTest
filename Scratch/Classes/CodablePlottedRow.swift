import Foundation
import CoreLocation

let defaultMachineWidth : Double = 120 // feet
let defaultMachineWidthMeters : Double = 27.432
let defaultRowCount : UInt = 54

enum DisplayType : UInt, CaseIterable, Codable {
    case singulation
    case rideQuality
    case downforce
}

typealias RowVariableInfo = [DisplayType : Float]

struct RowDataInfo : Codable {
    var rowId : UInt
    var rowState : Bool
    var rowVariables : RowVariableInfo
}
typealias RowDataInfoArray = [RowDataInfo]

struct PlottedRowBase : Codable {
    var location : CLLocationCoordinate2D?
    var dataInfo : RowDataInfoArray
    var rowHeading : Double
    var speed : Double
    var masterRowState : Bool
    
    enum CodingKeys: String, CodingKey {
        case location
        case rowInfoArr
        case rowDataInfoArr
        case rowHeading = "heading"
        case speed
        case masterRowState
    }
    
    init(location : CLLocationCoordinate2D, heading : Double, speed : Double, masterRowState: Bool, infoData: RowDataInfoArray) {
        self.location = location
        self.rowHeading = heading
        self.speed = speed
        self.masterRowState = masterRowState
        self.dataInfo = infoData
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        location = try values.decode(CLLocationCoordinate2D.self, forKey: .location)
        rowHeading = try values.decode(Double.self, forKey: .rowHeading)
        dataInfo = try values.decode(RowDataInfoArray.self, forKey: .rowDataInfoArr)
        speed = try values.decode(Double.self, forKey: .speed)
        masterRowState = try values.decode(Bool.self, forKey: .masterRowState)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(self.rowHeading, forKey: .rowHeading)
        try container.encode(self.dataInfo, forKey: .rowDataInfoArr)
        try container.encode(self.speed, forKey: .speed)
        try container.encode(self.masterRowState, forKey: .masterRowState)
    }
}
