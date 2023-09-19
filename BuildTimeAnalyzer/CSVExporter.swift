//
//  CSVExporter.swift
//  BuildTimeAnalyzer
//
//  Created by Bruno Resende on 16.01.19.
//  Copyright © 2019 Cane Media Ltd. All rights reserved.
//

import Foundation

struct CSVExporter {

    static var filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    func filename(with prefix: String) -> String {
        return "\(prefix)_\(CSVExporter.filenameDateFormatter.string(from: Date())).csv"
    }

    func export<T>(elements: [T], to url: URL) throws where T: CSVExportable {

        guard let data = elements.joinedAsCSVString(delimiter: .doubleQuote).data(using: .utf8) else {
            throw ExportErrors.couldNotParseStringAsUTF8
        }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw ExportErrors.fileIO(error)
        }
    }

    enum ExportErrors: Error {
        case couldNotParseStringAsUTF8
        case fileIO(Error)
    }
}

enum CSVDelimiter: String {
    case singleQuote = "'"
    case doubleQuote = "\""
    case none = ""
}

protocol CSVExportable {

    static var csvHeaderLine: String { get }

    var csvLine: String { get }
}

extension Array where Element: CSVExportable {

    func joinedAsCSVString(delimiter: CSVDelimiter) -> String {

        return ([Element.csvHeaderLine] + self.map({ $0.csvLine })).joined(separator: "\n")
    }
}

extension Array where Element == String {

    func joinedAsCSVLine(delimiter: CSVDelimiter) -> String {

        let formatter: (String) -> String

        switch delimiter {
        case .singleQuote:  formatter = { $0.replacingOccurrences(of: "'", with: "\\'") }
        case .doubleQuote:  formatter = { $0.replacingOccurrences(of: "\"", with: "\\\"") }
        case .none:         formatter = { $0 }
        }

        return self.map({ "\(delimiter.rawValue)\(formatter($0))\(delimiter.rawValue)" }).joined(separator: ",")
    }
}
