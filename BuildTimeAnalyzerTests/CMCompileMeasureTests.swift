//
//  CMCompileMeasureTests.swift
//  CMBuildTimeAnalyzerTests
//
//  Created by Robert Gummesson on 02/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import XCTest

class BuildTimeAnalyzerTests: XCTestCase {
    
    func testInit() {
        // Given
        let time = 25.3
        let timeString = "\(time)ms"
        let filename = "Code.Swift"
        let fileInfo = "\(filename):10:23"
        let location = 10
        let folder = "/User/JohnAppleseed/"
        let path = "\(folder)\(filename)"
        let rawPath = "\(folder)\(fileInfo)"
        let code = "some code"
        
        // When
        let resultOptional = CMCompileMeasure(time: time, rawPath: rawPath, code: code)
        
        // Then 
        XCTAssertNotNil(resultOptional)
        guard let result = resultOptional else { return }
        
        XCTAssertEqual(result.time, time)
        XCTAssertEqual(result.code, code)
        XCTAssertEqual(result.path, path)
        XCTAssertEqual(result.fileInfo, fileInfo)
        XCTAssertEqual(result.filename, filename)
        XCTAssertEqual(result.location, location)
        XCTAssertEqual(result.timeString, timeString)
    }
}
