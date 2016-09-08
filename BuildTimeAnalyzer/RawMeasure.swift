//
//  RawMeasure.swift
//  BuildTimeAnalyzer
//

import Foundation

struct RawMeasure {
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

extension RawMeasure: Equatable {}

func ==(lhs: RawMeasure, rhs: RawMeasure) -> Bool {
    return lhs.time == rhs.time && lhs.text == rhs.text
}

// MARK: Hashable

extension RawMeasure: Hashable {
    var hashValue: Int {
        return time.hashValue ^ text.hashValue
    }
}
