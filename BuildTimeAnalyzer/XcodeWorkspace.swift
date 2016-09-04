//
//  XcodeWorkSpace.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 30/04/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Cocoa

protocol XcodeWorkSpaceProtocol {
    var focusLostHandler: (() -> ())? { get set }
    
    func willOpenDocument(atLineNumber lineNumber: Int, usingTextView textView: NSTextView?)
}

extension XcodeWorkSpaceProtocol {
    
    func logText(forCacheAtPath path: String, completionHandler: ((_ text: String?) -> ())) {
        guard let lastBuild = lastBuildKey(fromPath: path),
            let folderURL = NSURL(fileURLWithPath: path).deletingLastPathComponent else {
            completionHandler(nil)
            return
        }
        let logFile = folderURL.appendingPathComponent(lastBuild).appendingPathExtension("xcactivitylog").path
        completionHandler(contentsOfFile(logFile))
    }
    
    mutating func openFile(atPath path: String, andLineNumber lineNumber: Int, focusLostHandler: (() -> ())) {
        _ = NSApp.delegate?.application?(NSApp, openFile: path)
    }
    
    fileprivate func lastBuildKey(fromPath path: String) -> String? {
        return lastDatabaseEntry(fromPath: path, usingFunction: { (key, value) -> String? in
            if let title = value["title"] as? String , title.hasPrefix("Build ") ||  title.hasPrefix("Compile "){
                return key
            }
            return nil
        })
    }
    
    fileprivate func lastSchemeName(fromPath path: String) -> String? {
        return lastDatabaseEntry(fromPath: path, usingFunction: { (key, value) -> String? in
            return value["schemeIdentifier-schemeName"] as? String
        })
    }
    
    fileprivate func lastDatabaseEntry(fromPath path: String, usingFunction f: (_ key: String, _ value: [String : AnyObject]) -> String?) -> String? {
        guard let data = NSDictionary(contentsOfFile: path)?["logs"] as? [String: AnyObject],
            let key = sortKeys(usingData: data).last?.key,
            let value = data[key] as? [String : AnyObject] else { return nil }
        
        return f(key, value)
    }
    
    fileprivate func sortKeys(usingData data: [String: AnyObject]) -> [(UInt, key: String)] {
        var sortedKeys: [(UInt, key: String)] = []
        for key in data.keys {
            if let value = data[key] as? [String: AnyObject],
                let timeStoppedRecording = value["timeStoppedRecording"] as? UInt {
                sortedKeys.append((timeStoppedRecording, key))
            }
        }
        return sortedKeys.sorted{ $0.0 < $1.0 }
    }
    
    fileprivate func contentsOfFile(_ path: String) -> String? {
        if let rawData = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let data = (rawData as NSData).gunzipped() {
            return String(data: data, encoding: String.Encoding.utf8)
        }
        return nil
    }
    
    fileprivate func creationDateForFile(_ path: String) -> Date? {
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: path)
        return fileAttributes?[FileAttributeKey.creationDate] as? Date
    }
}

class XcodeWorkSpace: NSObject, XcodeWorkSpaceProtocol {
    
    var lineNumber = 0
    var focusLostHandler: (() -> ())?
    
    func willOpenDocument(atLineNumber lineNumber: Int, usingTextView textView: NSTextView?) {
        self.lineNumber = lineNumber
        if let textView = textView {
            adjustSelection(forTextView: textView)
        }
    }
    
    func adjustSelection(forTextView textView: NSTextView?) {
        guard let textView = textView, let text = textView.textStorage?.string else { return }
        
        let subSequences = text.characters.split(separator: "\n", omittingEmptySubsequences: false)
        let lineCount = subSequences.count > lineNumber ? lineNumber : subSequences.count
        
        var characterCount = 0
        subSequences.dropLast(subSequences.count - lineCount).forEach({ (subSequence) in
            characterCount += String(subSequence).characters.count
        })
        
        let range = NSMakeRange(characterCount + lineNumber - 1, 0)
        if range.location < text.characters.count {
            textView.selectedRange = range
            textView.scrollRangeToVisible(range)
        }
    }
}
