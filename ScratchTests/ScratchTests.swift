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

    let mercator = GlobalMercator(tileSize: 256.0)

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

    func testLatLonToMeters() throws {
        let meters = GlobalMercator(tileSize: 256.0).LatLonToMeters(lat: 62.3, lon: 14.1)
        XCTAssertEqual(meters.X, 1569604.8201851572, accuracy: 0.000000001)
        XCTAssertEqual(meters.Y, 8930630.669201756, accuracy: 0.00000001)
    }

    func testMetersToLatLon() throws {
        let meters = GlobalMercator(tileSize: 256.0).MetersToLatLon(mx: 1569604.8201851572, my: 8930630.669201756)
        XCTAssertEqual(meters.X, 62.3, accuracy: 0.1)
        XCTAssertEqual(meters.Y, 14.1, accuracy: 0.1)
    }

    func testPixelsToMeters() throws {
        var meters = mercator.PixelsToMeters(px: 128, py: 128, zoom: 0)
        XCTAssertEqual(meters.X, 0)
        XCTAssertEqual(meters.Y, 0)
        
        meters = mercator.PixelsToMeters(px: 123456789, py: 123456789, zoom: 15)
        XCTAssertEqual(meters.X, 569754371.206588, accuracy: 0.000000001)
        XCTAssertEqual(meters.Y, 569754371.206588, accuracy: 0.00000001)
    }

    func testMetersToPixels() throws {
        let mercator = GlobalMercator(tileSize: 256.0)
        var meters = mercator.MetersToPixels(mx: 0, my: 0, zoom: 0)
        XCTAssertEqual(meters.X, 128, accuracy: 0.1)
        XCTAssertEqual(meters.Y, 128, accuracy: 0.1)

        meters = mercator.MetersToPixels(mx: 569754371.206588, my: 569754371.206588, zoom: 15)
        XCTAssertEqual(meters.X, 123456789)
        XCTAssertEqual(meters.Y, 123456789)

        meters = mercator.MetersToPixels(mx: 1473870.058102942, my: 6856372.69101939, zoom: 7)
        XCTAssertEqual(meters.X, 17589.134222222223, accuracy: 0.000000001)
        XCTAssertEqual(meters.Y, 21990.22649522623, accuracy: 0.00000001)

    }
    
    func testLatLonToPixels() {
//        aproxArrayEqual([4522857.8133333335, 6063687.123767246], mercator.latLonToPixels(62.3, 14.1, 15));
        let latLon = mercator.LatLonToPixels(lat: 62.3, lon: 14.1, zoom: 15)
        XCTAssertEqual(latLon.X, 4522857.8133333335, accuracy: 0.000000001)
        XCTAssertEqual(latLon.Y, 6063687.123767246, accuracy: 0.00000001)

        let latLon11 = mercator.LatLonToPixels(lat: 52.31, lon: 13.24, zoom: 7 )
        XCTAssertEqual(latLon11.X, 17589.134222222223, accuracy: 0.000000001)
        XCTAssertEqual(latLon11.Y, 21990.22649522623, accuracy: 0.00000001)

    }
    
    func testLatLonToTile() {
        let tile = mercator.LatLonToTile(lat: 52.31, lon: 13.24, zoom: 7)
        XCTAssertEqual(tile.X, 68)
        XCTAssertEqual(tile.Y, 85)
        
        let googleTile = mercator.GoogleTile(tx: tile.X, ty: tile.Y, zoom: 7)
        XCTAssertEqual(googleTile.X, 68)
        XCTAssertEqual(googleTile.Y, 42)
    }

    func testPixelsToLatLon() {
        var latLon = mercator.PixelsToLatLon(px: 4522857.8133333335, py: 6063687.123767246, zoom: 15)
        XCTAssertEqual(latLon.X, 62.3, accuracy: 0.1)
        XCTAssertEqual(latLon.Y, 14.1, accuracy: 0.1)
    }

    /*
     it('should return tile bounds', function () {
     var expected = [ 569754270.8829883, 569754270.8829883, 569755493.875441, 569755493.875441];
     aproxArrayEqual(expected, mercator.tileBounds(482253, 482253, 15));
     });
     */
    func testTileBounds() {
        let bounds = mercator.TileBounds(tx: 482253, ty: 482253, zoom: 15)
        XCTAssertEqual(bounds.North, 569755493.875441, accuracy: 0.00000001)
        XCTAssertEqual(bounds.South, 569754270.8829883, accuracy: 0.00000001)
        XCTAssertEqual(bounds.West, 569754270.8829883, accuracy: 0.00000001)
        XCTAssertEqual(bounds.East, 569755493.875441, accuracy: 0.00000001)
    }
    
    /*
     it('should return tile latlon bounds', function () {
     aproxArrayEqual([ -85.05112877980659, -180, -85.05018093458115, -179.989013671875], mercator.tileLatLonBounds(0, 0, 15));
     aproxArrayEqual([85.0511287798066, 180, 85.05207644397983, 180.010986328125], mercator.tileLatLonBounds(32768, 32768, 15));
     });
     */
    
    func testTileLatLonBounds() {
        let tileBounds = mercator.TileLatLonBounds(tx: 0, ty: 0, zoom: 15)
        XCTAssertEqual(tileBounds.North, -179.989013671875, accuracy: 0.00000001)
        XCTAssertEqual(tileBounds.South, -180, accuracy: 0.00000001)
        XCTAssertEqual(tileBounds.West, -85.05112877980659, accuracy: 0.00000001)
        XCTAssertEqual(tileBounds.East, -85.05018093458115, accuracy: 0.00000001)
    }
    
//    func testLatLong() {
//        // 41.85, -87.65
////        let merc = GlobalMercator(tileSize: 512.0)
//        let coord = CLLocationCoordinate2DMake(41.85, -87.65)
//        let pixels = mercator.LatLonToPixels(lat: coord.latitude, lon: coord.longitude, zoom: 14)
//        let pixelCoords = MBUtils.getPixelCoordinates(latLng: coord, zoom: 7)
//        debugPrint("\(pixels), \(pixelCoords)")
////        let tileBounds = mercator.TileBounds(tx: <#T##Double#>, ty: <#T##Double#>, zoom: <#T##UInt#>)
//    }
}
