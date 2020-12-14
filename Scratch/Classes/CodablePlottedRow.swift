import Foundation
import CoreLocation

typealias DataRowValues = Array<Float>
typealias PlottedRowData = [UInt : DataRowValues]

let defaultMachineWidth : Double = 120 // feet
let defaultMachineWidthMeters : Double = 27.432
let defaultRowCount : UInt = 54

struct PlottedRowBase : Codable {
    var location : CLLocationCoordinate2D?
    var rowInfoArr : PlottedRowData
    var rowHeading : Double
    var speed : Double
    
    enum CodingKeys: String, CodingKey {
        case location
        case rowInfoArr
        case rowHeading = "heading"
        case speed
    }
    
    init(location : CLLocationCoordinate2D, heading : Double, speed : Double,  rows: PlottedRowData) {
        self.location = location
        self.rowHeading = heading
        self.rowInfoArr = rows
        self.speed = speed
    }
    
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        location = try values.decode(CLLocationCoordinate2D.self, forKey: .location)
        rowHeading = try values.decode(Double.self, forKey: .rowHeading)
        rowInfoArr = try values.decode(PlottedRowData.self, forKey: .rowInfoArr)
        speed = try values.decode(Double.self, forKey: .speed)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        //        try container.encode(longitude, forKey: .longitude)
        try container.encode(self.rowHeading, forKey: .rowHeading)
        try container.encode(self.rowInfoArr, forKey: .rowInfoArr)
        try container.encode(self.speed, forKey: .speed)
    }
}
