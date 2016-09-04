//
//  CMLogProcessor.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Foundation

typealias CMUpdateClosure = (_ result: [CMCompileMeasure], _ didComplete: Bool) -> ()

protocol CMLogProcessorProtocol: class {
    var rawMeasures: [String: CMRawMeasure] { get set }
    var updateHandler: CMUpdateClosure? { get set }
    var workspace: CMXcodeWorkSpace? { get set }
    var shouldCancel: Bool { get set }
    
    func processingDidStart()
    func processingDidFinish()
}

extension CMLogProcessorProtocol {
    func processCacheFile(at path: String, updateHandler: CMUpdateClosure?) {
        workspace = CMXcodeWorkSpace()
        workspace?.logText(forCacheAtPath: path) { [weak self] (text) in
            guard let text = text else {
                updateHandler?([], true)
                return
            }
            
            self?.updateHandler = updateHandler
            DispatchQueue.global().async {
                self?.process(text: text)
            }
        }
    }
    
    // MARK: Private methods
    
    fileprivate func process(text: String) {
        let characterSet = CharacterSet(charactersIn:"\r\"")
        var remainingRange = text.startIndex..<text.endIndex
        let regex = try! NSRegularExpression(pattern:  "^\\d*\\.?\\dms\\t/", options: [])
        
        rawMeasures.removeAll()
        
        processingDidStart()
        
        while let nextRange = text.rangeOfCharacter(from: characterSet, options: [], range: remainingRange) {
            let text = text.substring(with: remainingRange.lowerBound..<nextRange.upperBound)
            
            defer {
                remainingRange = nextRange.upperBound..<remainingRange.upperBound
            }
            
            let range = NSMakeRange(0, text.characters.count)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }
            
            let timeString = text.substring(to: text.characters.index(text.startIndex, offsetBy: match.range.length - 4))
            if let time = Double(timeString) {
                let value = text.substring(from: text.characters.index(text.startIndex, offsetBy: match.range.length - 1))
                if var rawMeasure = rawMeasures[value] {
                    rawMeasure.time += time
                    rawMeasure.references += 1
                    rawMeasures[value] = rawMeasure
                } else {
                    rawMeasures[value] = CMRawMeasure(time: time, text: value)
                }
            }
            guard !shouldCancel else { break }
        }
        processingDidFinish()
    }
    
    fileprivate func updateResults(_ didComplete: Bool) {
        var filteredResults = rawMeasures.values.filter({ $0.time > 10 })
        if filteredResults.count < 20 {
            filteredResults = rawMeasures.values.filter({ $0.time > 0.1 })
        }
        
        let sortedResults = filteredResults.sorted(by: { $0.time > $1.time })
        updateHandler?(processResult(sortedResults), didComplete)
        
        if didComplete {
            rawMeasures.removeAll()
        }
    }
    
    fileprivate func processResult(_ unprocessedResult: [CMRawMeasure]) -> [CMCompileMeasure] {
        var result: [CMCompileMeasure] = []
        for entry in unprocessedResult {
            let code = entry.text.characters.split(separator: "\t").map(String.init)
            if code.count >= 2, let measure = CMCompileMeasure(time: entry.time, rawPath: code[0], code: trimPrefixes(code[1]), references: entry.references) {
                result.append(measure)
            }
        }
        return result
    }
    
    fileprivate func trimPrefixes(_ code: String) -> String {
        var code = code
        ["@objc ", "final ", "@IBAction "].forEach { (prefix) in
            if code.hasPrefix(prefix) {
                code = code.substring(from: code.index(code.startIndex, offsetBy: prefix.characters.count))
            }
        }
        return code
    }
}

class CMLogProcessor: NSObject, CMLogProcessorProtocol {
    
    var rawMeasures: [String: CMRawMeasure] = [:]
    var updateHandler: CMUpdateClosure?
    var workspace: CMXcodeWorkSpace?
    var shouldCancel = false
    var timer: Timer?
    
    func processingDidStart() {
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(self.timerCallback(_:)), userInfo: nil, repeats: true)
        }
    }
    
    func processingDidFinish() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
            self.shouldCancel = false
            self.updateResults(true)
        }
    }
    
    func timerCallback(_ timer: Timer) {
        updateResults(false)
    }
}
