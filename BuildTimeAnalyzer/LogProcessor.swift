//
//  LogProcessor.swift
//  BuildTimeAnalyzer
//

import Foundation

typealias CMUpdateClosure = (_ result: [CompileMeasure], _ didComplete: Bool, _ didCancel: Bool) -> ()

fileprivate let regex = try! NSRegularExpression(pattern:  "^\\d*\\.?\\d*ms\\t/", options: [])

protocol LogProcessorProtocol: AnyObject {
    var rawMeasures: [String: RawMeasure] { get set }
    var updateHandler: CMUpdateClosure? { get set }
    var shouldCancel: Bool { get set }
    
    func processingDidStart()
    func processingDidFinish()
}

class LogProcessor: NSObject, LogProcessorProtocol {
    
    var rawMeasures: [String: RawMeasure] = [:]
    var updateHandler: CMUpdateClosure?
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
            let didCancel = self.shouldCancel
            self.shouldCancel = false
            self.updateResults(didComplete: true, didCancel: didCancel)
        }
    }
    
    @objc func timerCallback(_ timer: Timer) {
        updateResults(didComplete: false, didCancel: false)
    }

    func processDatabase(database: XcodeDatabase, updateHandler: CMUpdateClosure?) {
        guard let text = database.processLog() else {
            updateHandler?([], true, false)
            return
        }

        self.updateHandler = updateHandler
        DispatchQueue.global(qos: .background).async {
            self.process(text: text)
        }
    }

    // MARK: Private methods

    private func process(text: String) {
        let characterSet = CharacterSet(charactersIn:"\r")
        var remainingRange = text.startIndex..<text.endIndex

        rawMeasures.removeAll()

        processingDidStart()

        while !shouldCancel, let characterRange = text.rangeOfCharacter(from: characterSet,
                                                                        options: .literal,
                                                                        range: remainingRange) {
            let nextRange = remainingRange.lowerBound..<characterRange.upperBound

            defer {
                remainingRange = nextRange.upperBound..<remainingRange.upperBound
            }

            let range = NSRange(nextRange, in: text)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }
            let matchRange = Range<String.Index>.init(match.range, in: text)!
            let timeString = text[remainingRange.lowerBound..<text.index(matchRange.upperBound, offsetBy: -4)]
            if let time = Double(timeString) {
                let value = String(text[text.index(before: matchRange.upperBound)..<nextRange.upperBound])
                if let rawMeasure = rawMeasures[value] {
                    rawMeasure.time += time
                    rawMeasure.references += 1
                } else {
                    rawMeasures[value] = RawMeasure(time: time, text: value)
                }
            }
        }
        processingDidFinish()
    }

    fileprivate func updateResults(didComplete completed: Bool, didCancel: Bool) {
        DispatchQueue.global(qos: .userInteractive).async {
            let measures = self.rawMeasures.values
            var filteredResults = measures.filter{ $0.time > 10 }
            if filteredResults.count < 20 {
                filteredResults = measures.filter{ $0.time > 0.1 }
            }

            let sortedResults = filteredResults.sorted(by: { $0.time > $1.time })
            let result = self.processResult(sortedResults)

            if completed {
                self.rawMeasures.removeAll()
            }

            DispatchQueue.main.async {
                self.updateHandler?(result, completed, didCancel)
            }
        }
    }

    private func processResult(_ unprocessedResult: [RawMeasure]) -> [CompileMeasure] {
        let characterSet = CharacterSet(charactersIn:"\r\"")

        var result: [CompileMeasure] = []
        for entry in unprocessedResult {
            let code = entry.text.split(separator: "\t").map(String.init)
            let method = code.count >= 2 ? trimPrefixes(code[1]) : "-"

            if let path = code.first?.trimmingCharacters(in: characterSet), let measure = CompileMeasure(time: entry.time, rawPath: path, code: method, references: entry.references) {
                result.append(measure)
            }
        }
        return result
    }

    private func trimPrefixes(_ code: String) -> String {
        var code = code
        ["@objc ", "final ", "@IBAction "].forEach { (prefix) in
            if code.hasPrefix(prefix) {
                code = String(code[code.index(code.startIndex, offsetBy: prefix.count)...])
            }
        }
        return code
    }
}
