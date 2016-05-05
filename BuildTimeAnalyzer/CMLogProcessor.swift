//
//  CMLogProcessor.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

typealias CMUpdateClosure = (result: [CMCompileMeasure], didComplete: Bool) -> ()

protocol CMLogProcessorProtocol: class {
    var unprocessedResult: [CMRawMeasure] { get set }
    var updateHandler: CMUpdateClosure? { get set }
    var workspace: CMXcodeWorkSpace? { get set }
    var shouldCancel: Bool { get set }
    
    func processingDidStart()
    func processingDidFinish()
}

extension CMLogProcessorProtocol {
    func process(productName: String, buildCompletionDate: NSDate?, updateHandler: ((result: [CMCompileMeasure], didComplete: Bool) -> ())?) {
        workspace = CMXcodeWorkSpace(productName: productName, buildCompletionDate: buildCompletionDate)
        workspace?.logTextForProduct() { [weak self] (text) in
            guard let text = text else {
                updateHandler?(result: [], didComplete: true)
                return
            }
            
            self?.updateHandler = updateHandler
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                self?.process(text: text)
            }
        }
    }
    
    // MARK: Private methods
    
    private func process(text text: String) {
        let locationPattern = "^\\d*\\.?\\dms\\t/"
        let matchingOption = NSMatchingOptions(rawValue: 0)
        let compareOptions = NSStringCompareOptions(rawValue: 0)
        let regexOptions = NSRegularExpressionOptions(rawValue: 0)
        let characterSet = NSCharacterSet(charactersInString:"\r")
        
        let regex = try! NSRegularExpression(pattern: locationPattern, options: regexOptions)
        
        var remainingRange = text.startIndex..<text.endIndex
        
        unprocessedResult.removeAll()
        processingDidStart()
        
        while let nextRange = text.rangeOfCharacterFromSet(characterSet, options: compareOptions, range: remainingRange) {
            let currentRange = remainingRange.startIndex..<nextRange.endIndex
            let text = text.substringWithRange(currentRange)
            
            defer { remainingRange = nextRange.endIndex..<remainingRange.endIndex }
            
            let range = NSMakeRange(0, text.characters.count)
            guard let match = regex.firstMatchInString(text, options: matchingOption, range: range) else { continue }
            
            let timeString = text.substringToIndex(text.startIndex.advancedBy(match.range.length - 4))
            if let time = Double(timeString) {
                let value = text.substringFromIndex(text.startIndex.advancedBy(match.range.length - 1))
                unprocessedResult.append(CMRawMeasure(time: time, text: value))
            }
            guard !shouldCancel else { break }
        }
        processingDidFinish()
    }
    
    private func updateResults(didComplete: Bool) {
        let cappedResult = capEntries(unprocessedResult)
        updateHandler?(result: processResult(cappedResult), didComplete: didComplete)
        
        if didComplete {
            unprocessedResult.removeAll()
        }
    }
    
    private func capEntries(entries: [CMRawMeasure]) -> [CMRawMeasure] {
        let limit = 20

        let distinct = Array(Set(entries))
        var sorted = distinct.sort{ $0.time > $1.time }
        if sorted.count > limit {
            sorted = Array(sorted[0..<limit])
        }
        return sorted
    }
    
    private func processResult(unprocessedResult: [CMRawMeasure]) -> [CMCompileMeasure] {
        let unprocessedResult = capEntries(unprocessedResult)
        
        var result: [CMCompileMeasure] = []
        for entry in unprocessedResult {
            let code = entry.text.characters.split("\t").map(String.init)
            if code.count >= 2, let measure = CMCompileMeasure(time: entry.time, rawPath: code[0], code: trimPrefixes(code[1])) {
                result.append(measure)
            }
        }
        return result
    }
    
    private func trimPrefixes(code: String) -> String {
        var code = code
        ["@objc ", "final ", "@IBAction "].forEach { (prefix) in
            if code.hasPrefix(prefix) {
                code = code.substringFromIndex(code.startIndex.advancedBy(prefix.characters.count))
            }
        }
        return code
    }
}

class CMLogProcessor: NSObject, CMLogProcessorProtocol {
    
    var unprocessedResult: [CMRawMeasure] = []
    var updateHandler: CMUpdateClosure?
    var workspace: CMXcodeWorkSpace?
    var shouldCancel = false
    var timer: NSTimer?
    
    func processingDidStart() {
        dispatch_async(dispatch_get_main_queue()) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(self.timerCallback(_:)), userInfo: nil, repeats: true)
        }
    }
    
    func processingDidFinish() {
        timer?.invalidate()
        timer = nil
        
        shouldCancel = false
        dispatch_async(dispatch_get_main_queue()) {
            self.updateResults(true)
        }
    }
    
    func timerCallback(timer: NSTimer) {
        updateResults(false)
    }
}