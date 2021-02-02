//
//  ScratchTests.swift
//  ScratchTests
//
//  Created by Jeremy Kercheval on 11/7/20.
//

import XCTest
import CoreLocation

@testable import Scratch

class ScratchTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    let json = """
{
        "serial": "1",
        "id": "d7535ce5-06a6-4f51-92de-76823bce27c3",
        "omCode": "M-ACT-PLT-RATE",
        "phentime": "2019-09-01T20:55:02",
        "lon": "-88.4551194",
        "lat": "36.5404538",
        "assetRef": "3284b28d-51af-46f4-8249-8c7f29fba8bd",
        "value": "35000",
        "uomCode": "seeds1ac-1",
        "taskref": "d53778fe-484c-49b2-a162-75c9da7e8f6a",
        "channel": "1",
        "section": "1",
        "box": "1",
        "fieldRef": "",
        "cropzoneRef": "",
        "param1": "PLANTING",
        "param2": "",
        "param3": ""
    }
"""
    func testDecodeSerialData() {
        let decoder = JSONDecoder()
        
        if let jsonData = json.data(using: .utf8) {
            
            do {
                let testData = try decoder.decode(SessionData.self, from: jsonData)
                XCTAssertNotNil(testData.location)
                XCTAssertEqual(String(testData.location!.latitude), testData.lat, "Latitude does not match")
                XCTAssertEqual(String(testData.location!.longitude), testData.lon, "Longitude does not match")

            } catch {
                print(error)
                XCTFail()
            }
        }
    }
    
    func testFileData() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.url(forResource: "data", withExtension: "json")//(forResource: "data", ofType: "json")!
        let jsonFileData = try? Data(contentsOf: path!)

        XCTAssertNotNil(jsonFileData)
        let decoder = JSONDecoder()
        if let jsonData = jsonFileData {
            do {
                let testData = try decoder.decode([SessionData].self, from: jsonData)
                XCTAssertNotNil(testData)
                XCTAssertEqual(testData.count, 2139, "Invlaid number of data items")                
            } catch {
                print(error)
                XCTFail()
            }
        }
    }
    
    func testDateConversionFromData() {
        let bundle = Bundle(for: type(of: self))
        let path = bundle.url(forResource: "data", withExtension: "json")//(forResource: "data", ofType: "json")!
        let jsonFileData = try? Data(contentsOf: path!)
        
        XCTAssertNotNil(jsonFileData)
        let decoder = JSONDecoder()
        if let jsonData = jsonFileData {
            do {
                let testData = try decoder.decode([SessionData].self, from: jsonData)
                XCTAssertNotNil(testData)
                XCTAssertEqual(testData.count, 2139, "Invlaid number of data items")
                guard let firstItem = testData.first else {
                    XCTFail("Failed to get first item")
                    return
                }
                let timeZone = TimeZone(secondsFromGMT: 0)
                let dateFormatterGet = DateFormatter()
                dateFormatterGet.locale = Locale(identifier: "en_US_POSIX")
                dateFormatterGet.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                dateFormatterGet.timeZone = timeZone
                
                guard let firstItemDate = dateFormatterGet.date(from: firstItem.phentime) else {
                    XCTFail("Failed to get date from formatter")
                    return
                }
                XCTAssertNotNil(firstItemDate, "Failed to convert date")
                print("Date is: \(firstItemDate)")
                
                let dateComponents = DateComponents(calendar: Calendar.current, timeZone: timeZone, era: nil, year: 2019, month: 9, day: 1, hour: 20, minute: 55, second: 2, nanosecond: nil, weekday: nil, weekdayOrdinal: nil, quarter: nil, weekOfMonth: nil, weekOfYear: nil, yearForWeekOfYear: nil)
                let testDate = Calendar.current.date(from: dateComponents)
                XCTAssertEqual(testDate, firstItemDate)
            } catch {
                print(error)
                XCTFail()
            }
        }

    }
}
