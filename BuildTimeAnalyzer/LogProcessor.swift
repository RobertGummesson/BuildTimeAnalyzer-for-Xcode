//
//  LogProcessor.swift
//  BuildTimeAnalyzer
//

import Foundation

typealias CMUpdateClosure = (_ result: [CompileMeasure], _ didComplete: Bool, _ didCancel: Bool) -> ()

protocol LogProcessorProtocol: class {
    var rawMeasures: [String: RawMeasure] { get set }
    var updateHandler: CMUpdateClosure? { get set }
    var shouldCancel: Bool { get set }

    func processingDidStart()
    func processingDidFinish()
}

extension LogProcessorProtocol {
    func processDatabase(database: XcodeDatabase, updateHandler: CMUpdateClosure?) {
        guard let text = database.processLog() else {
            updateHandler?([], true, false)
            return
        }

        self.updateHandler = updateHandler
        DispatchQueue.global().async {
            self.process(text: text)
        }
    }

    // MARK: Private methods

    private func process(text: String) {
        let characterSet = CharacterSet(charactersIn:"\r\"")
        var remainingRange = text.startIndex..<text.endIndex
        let regex = try! NSRegularExpression(pattern:  "^\\d*\\.?\\d*ms\\t/", options: [])

        rawMeasures.removeAll()

        processingDidStart()

        while let nextRange = text.rangeOfCharacter(from: characterSet, options: [], range: remainingRange) {
            let text = String(text[remainingRange.lowerBound..<nextRange.upperBound])

            defer {
                remainingRange = nextRange.upperBound..<remainingRange.upperBound
            }

            // From LuizZak: (text as NSString).length improves the performance by about 2x compared to text.characters.count
            let range = NSMakeRange(0, (text as NSString).length)
            guard let match = regex.firstMatch(in: text, options: [], range: range) else { continue }

            let timeString = text[..<text.index(text.startIndex, offsetBy: match.range.length - 4)]
            if let time = Double(timeString) {
                let value = String(text[text.index(text.startIndex, offsetBy: match.range.length - 1)...])
                if var rawMeasure = rawMeasures[value] {
                    rawMeasure.time += time
                    rawMeasure.references += 1
                    rawMeasures[value] = rawMeasure
                } else {
                    rawMeasures[value] = RawMeasure(time: time, text: value)
                }
            }
            guard !shouldCancel else { break }
        }
        processingDidFinish()
    }

    fileprivate func updateResults(didComplete completed: Bool, didCancel: Bool) {
        var filteredResults = rawMeasures.values.filter{ $0.time > 10 }
        if filteredResults.count < 20 {
            filteredResults = rawMeasures.values.filter{ $0.time > 0.1 }
        }

        let sortedResults = filteredResults.sorted(by: { $0.time > $1.time })
        updateHandler?(processResult(sortedResults), completed, didCancel)

        if completed {
            rawMeasures.removeAll()
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
}
