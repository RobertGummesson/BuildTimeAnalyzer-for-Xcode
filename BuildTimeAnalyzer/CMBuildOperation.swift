//
//  CMBuildOperation.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 03/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Foundation

enum CMBuildResult : Int {
    case success = 1
    case failed = 2
    case cancelled = 3
}

struct CMBuildOperation {
    
    var actionName: String
    var productName: String
    var duration: Double
    var result: CMBuildResult
    var startTime: Date
    
    var endTime: Date {
        // We will be looking for log files created after this date
        // Let's subtract a second to be on the safe side
        return startTime.addingTimeInterval(duration - 1)
    }
}
