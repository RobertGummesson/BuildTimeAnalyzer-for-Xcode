//
//  CompileMeasure.swift
//  BuildTimeAnalyzer
//

import Foundation

@objcMembers class CompileMeasure: NSObject {
    
    dynamic var time: Double
    var path: String
    var code: String
    dynamic var filename: String
    var references: Int

    private var locationArray: [Int]

    public enum Order: String {
        case filename
        case time
    }

    var fileAndLine: String {
        return "\(filename):\(locationArray[0])"
    }

    var fileInfo: String {
        return "\(fileAndLine):\(locationArray[1])"
    }
    
    var location: Int {
        return locationArray[0]
    }
    
    var timeString: String {
        return String(format: "%.1fms", time)
    }
    
    init?(time: Double, rawPath: String, code: String, references: Int) {
        let untrimmedFilename: Substring
        if let lastIdx = rawPath.lastIndex(of: "/") {
            untrimmedFilename = rawPath.suffix(from: rawPath.index(after: lastIdx))
        } else {
            untrimmedFilename = rawPath[...]
        }
        let filepath = rawPath.prefix(while: {$0 != ":"})
        let filename = untrimmedFilename.prefix(while: {$0 != ":"})
        let locations = untrimmedFilename.split(separator: ":").dropFirst().compactMap({Int(String($0))})
        guard locations.count == 2 else { return nil }
        
        self.time = time
        self.code = code
        self.path = String(filepath)
        self.filename = String(filename)
        self.locationArray = locations
        self.references = references
    }

    init?(rawPath: String, time: Double) {
        let untrimmedFilename = rawPath.split(separator: "/").map(String.init).last

        guard let filepath = rawPath.split(separator: ":").map(String.init).first,
            let filename = untrimmedFilename?.split(separator: ":").map(String.init).first else { return nil }

        self.time = time
        self.code = ""
        self.path = filepath
        self.filename = filename
        self.locationArray = [1,1]
        self.references = 1
    }

    subscript(column: Int) -> String {
        switch column {
        case 0:
            return timeString
        case 1:
            return fileInfo
        case 2:
            return "\(references)"
        default:
            return code
        }
    }
}
