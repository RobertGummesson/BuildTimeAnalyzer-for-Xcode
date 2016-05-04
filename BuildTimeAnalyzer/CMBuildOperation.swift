//
//  CMBuildOperation.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 03/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Foundation

struct CMBuildOperation {
    
    var actionName: String
    var productName: String
    var duration: Double
    var result: Int
    var startTime: NSDate
    
    var endTime: NSDate {
        // We will be looking for log files created after this date
        // Let's subtract a second to be on the safe side
        return startTime.dateByAddingTimeInterval(duration - 1000)
    }
}