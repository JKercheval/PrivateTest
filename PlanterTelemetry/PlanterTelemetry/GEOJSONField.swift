//
//  GEOJSONField.swift
//  PlanterTelemetry
//
//  Created by Jeremy Kercheval on 12/10/20.
//

import Foundation
import GEOSwift

class GeoJSONField {
    private var jsonData : Data?
    
    var data : Data? {
        get {
            return jsonData
        }
    }
    
    var fieldEnvelope : Envelope? {
        get {
            guard let data = jsonData, let geoJson = try? JSONDecoder().decode(GeoJSON.self, from: data) else {
                return nil
            }
            switch (geoJson) {
                case .featureCollection(let featureCollection):
                    let feild = featureCollection.features.first?.geometry
                    return try? feild?.envelope()
                case .feature(_):
                    break
                case .geometry(_):
                    break
            }
            return nil
        }
    }
    
    var northWest : CLLocationCoordinate2D {
        get {
            if let envelope = fieldEnvelope {
                return CLLocationCoordinate2D(latitude: envelope.maxY, longitude: envelope.minX)
            }
            return CLLocationCoordinate2D()
        }
    }
    
    var southWest : CLLocationCoordinate2D {
        get {
            if let envelope = fieldEnvelope {
                return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.minX)
            }
            return CLLocationCoordinate2D()
        }
    }
    
    var southEast : CLLocationCoordinate2D {
        get {
            if let envelope = fieldEnvelope {
                return CLLocationCoordinate2D(latitude: envelope.minY, longitude: envelope.maxX)
            }
            return CLLocationCoordinate2D()
        }
    }
    
    var northEast : CLLocationCoordinate2D {
        get {
            if let envelope = fieldEnvelope {
                return CLLocationCoordinate2D(latitude: envelope.maxY, longitude: envelope.maxX)
            }
            return CLLocationCoordinate2D()
        }
    }
    
    init(fieldName : String) {
        jsonData = loadGeoJson(jsonFileName: fieldName)
    
    }
    
    private func loadGeoJson(jsonFileName : String) ->Data {
        
        // Get the path for example.geojson in the app’s bundle.
        guard let jsonUrl = Bundle.main.url(forResource: jsonFileName, withExtension: "geojson") else {
            preconditionFailure("Failed to load local GeoJSON file")
        }
        
        guard let jsonData = try? Data(contentsOf: jsonUrl) else {
            preconditionFailure("Failed to parse GeoJSON file")
        }
        
        return jsonData
    }

}

class FieldBoundaryCorners {
    var northWest : CLLocationCoordinate2D
    var southEast : CLLocationCoordinate2D
    var northEast : CLLocationCoordinate2D
    var southWest : CLLocationCoordinate2D
    
    init(withCoordinates northWest : CLLocationCoordinate2D, southEast : CLLocationCoordinate2D,
         northEast : CLLocationCoordinate2D, southWest : CLLocationCoordinate2D) {
        self.northWest = northWest
        self.southEast = southEast
        self.northEast = northEast
        self.southWest = southWest
    }
}
