//
//  NSDate+Comparable.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 28/06/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Foundation

extension NSDate: Comparable { }

public func ==(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == .OrderedSame
}

public func <(lhs: NSDate, rhs: NSDate) -> Bool {
    return lhs.compare(rhs) == .OrderedAscending
}