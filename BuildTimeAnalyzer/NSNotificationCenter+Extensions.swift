//
//  NSNotificationCenter+Extensions.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

extension NSNotificationCenter {
    
    static func removeObserver(observer: AnyObject?, name: String) {
        if let observer = observer {
            NSNotificationCenter.defaultCenter().removeObserver(observer, name: name, object: nil)
        }
    }
    
    static func addObserverForName(name: String?, usingBlock block: (NSNotification) -> Void) -> NSObjectProtocol {
        return NSNotificationCenter.defaultCenter().addObserverForName(name, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: block)
    }
}