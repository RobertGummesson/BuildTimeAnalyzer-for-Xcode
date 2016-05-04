//
//  CMCompileMeasure.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 02/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Foundation

struct CMCompileMeasure {
    
    var time: Double
    var path: String
    var code: String
    var filename: String
    
    private var locationArray: [Int]
    
    var fileInfo: String {
        return "\(filename):\(locationArray[0]):\(locationArray[1])"
    }
    
    var location: Int {
        return locationArray[0]
    }
    
    var timeString: String {
        return "\(time)ms"
    }
    
    init?(time: Double, rawPath: String, code: String) {
        let untrimmedFilename = rawPath.characters.split("/").map(String.init).last
        
        guard let filepath = rawPath.characters.split(":").map(String.init).first else { return nil }
        guard let filename = untrimmedFilename?.characters.split(":").map(String.init).first else { return nil }
        
        let locationString = String(rawPath.substringFromIndex(filepath.endIndex).characters.dropFirst())
        let locations = locationString.characters.split(":").map(String.init).flatMap{ Int($0) }
        guard locations.count == 2 else { return nil }
        
        self.time = time
        self.code = code
        self.path = filepath
        self.filename = filename
        self.locationArray = locations
    }
    
    subscript(column: Int) -> String {
        get {
            switch column {
            case 0:
                return timeString
            case 1:
                return fileInfo
            default:
                return code
            }
        }
    }
}