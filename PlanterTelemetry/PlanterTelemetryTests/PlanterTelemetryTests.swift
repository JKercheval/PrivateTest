//
//  PlanterTelemetryTests.swift
//  PlanterTelemetryTests
//
//  Created by Jeremy Kercheval on 12/10/20.
//

import XCTest
@testable import PlanterTelemetry

class PlanterTelemetryTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testFileData() throws {
        let bundle = Bundle.main// Bundle(for: type(of: self))
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
}
