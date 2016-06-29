//
//  CMRawMeasure.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 04/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Foundation

struct CMRawMeasure {
    var time: Double
    var text: String
    var references: Int
    
    init(time: Double, text: String) {
        self.time = time
        self.text = text
        self.references = 1
    }
}

// MARK: Equatable

extension CMRawMeasure: Equatable {}

func ==(lhs: CMRawMeasure, rhs: CMRawMeasure) -> Bool {
    return lhs.time == rhs.time && lhs.text == rhs.text
}

// MARK: Hashable

extension CMRawMeasure: Hashable {
    var hashValue: Int {
        return time.hashValue ^ text.hashValue
    }
}
