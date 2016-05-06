//
//  CMXcodeWorkspace.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 30/04/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Cocoa

protocol CMXcodeWorkspaceProtocol {
    var retryAttempts: Int { get }
    var productName: String { get set }
    var buildCompletionDate: NSDate? { get set }
    
    init(productName: String, buildCompletionDate: NSDate?)
    func logTextForProduct(attemptIndex: Int, completionHandler: ((text: String?) -> ()))
}

extension CMXcodeWorkspaceProtocol {
    func logTextForProduct(attemptIndex: Int = 0, completionHandler: ((text: String?) -> ())) {
        guard let buildFolderPath = buildFolderPath(productName),
            let buildFolderURL = NSURL(string: buildFolderPath),
            let filenames = filesAtURL(buildFolderURL) else {
                completionHandler(text: nil)
                return
        }
        
        var keyFilename: String?
        var creationDates: [String: NSDate] = [:]
        parseFiles(filenames, buildFolderURL: buildFolderURL, keyFilename: &keyFilename, creationDates: &creationDates)
        
        var lastLogPath: String?
        var lastLogCreationDate: NSDate?
        if let keyFilename = keyFilename, filename = buildFolderURL.URLByAppendingPathComponent(keyFilename).path {
            lastLogPath = filename
            lastLogCreationDate = creationDates[keyFilename]
        }
        validatePath(lastLogPath, creationDate: lastLogCreationDate, attemptIndex: attemptIndex, completionHandler: completionHandler)
    }
    
    func productWorkspace() -> AnyObject? {
        guard let windowController = NSClassFromString("IDEWorkspaceWindowController") else { return nil }
        guard let windowControllers = windowController.valueForKey("workspaceWindowControllers") as? [AnyObject] else { return nil }
        guard let keyWindow = windowControllers.filter({ ($0.valueForKeyPath("_workspace.name") as? String) == productName }).first else {
            return locateWorkspace(fromWindowControllers: windowControllers)
        }
        return keyWindow.valueForKey("_workspace")
    }
    
    func buildFolderFromWorkspace(workspace: AnyObject?) -> NSURL? {
        return (workspace?.valueForKeyPath("_workspaceArena.logFolderPath.fileURL") as? NSURL)?.URLByAppendingPathComponent("Build")
    }
    
    func buildFolderPath(productName: String) -> String? {
        return buildFolderFromWorkspace(productWorkspace())?.path
    }
    
    // MARK: Static methods
    
    static func openFile(atPath path: String, andLineNumber lineNumber: Int) {
        
        NSApp.delegate?.application?(NSApp, openFile: path)
        
        // NOTE: the following is a bit of a hacky approach
        // using applescript to try and go to the line number
        // We start with a sleep delay of x seconds and hope that 
        // the application has opened the file within that window
        // instead of waiting for a notification
        var gotoLineNumber = ""
        gotoLineNumber = gotoLineNumber + "do shell script \"sleep 0.3\" #catchup"
        gotoLineNumber = gotoLineNumber + "\ntell application \"XCode\""
        gotoLineNumber = gotoLineNumber + "\n   activate"
        gotoLineNumber = gotoLineNumber + "\n   tell application \"System Events\" to key code 37 using command down #send command L"
        gotoLineNumber = gotoLineNumber + "\n   tell application \"System Events\" to keystroke \(lineNumber)"
        gotoLineNumber = gotoLineNumber + "\n   tell application \"System Events\" to keystroke return"
        gotoLineNumber = gotoLineNumber + "\nend tell"
        if let script = NSAppleScript(source: gotoLineNumber) {
            var error:NSDictionary? = nil
            script.executeAndReturnError(&error)
            // FIXME: silently ignore errors?
        }
    }
    
    static func buildOperation(fromData data: AnyObject?) -> CMBuildOperation? {
        guard let actionName = data?.valueForKeyPath("_buildOperationDescription._actionName") as? String,
            let productName = data?.valueForKeyPath("_buildOperationDescription._objectToBuildName") as? String,
            let duration = data?.valueForKey("duration") as? Double,
            let result = data?.valueForKey("_result") as? Int,
            let startTime = data?.valueForKey("_startTime") as? NSDate else {
                return nil
        }
        return CMBuildOperation(actionName: actionName, productName: productName, duration: duration, result: result, startTime: startTime)
    }
    
    // MARK: Private methods
    
    private func locateWorkspace(fromWindowControllers windowControllers: [AnyObject]) -> AnyObject? {
        if windowControllers.count == 1 {
            return windowControllers.first?.valueForKey("_workspace")
        } else {
            for controller in windowControllers {
                if let workspace = controller.valueForKey("_workspace"),
                    let logFolderURL = buildFolderFromWorkspace(workspace),
                    let files = filesAtURL(logFolderURL),
                    let filename = files.filter({ $0.hasSuffix(".db") }).first,
                    let path = logFolderURL.URLByAppendingPathComponent(filename).path,
                    let schemeName = lastSchemeName(fromPath: path) where schemeName == productName {
                    return workspace
                }
            }
        }
        return nil
    }
    
    private func filesAtURL(url: NSURL) -> [String]? {
        guard let path = url.path, enumerator = NSFileManager.defaultManager().enumeratorAtPath(path) else { return nil }
        
        var result: [String] = []
        for file in enumerator {
            if let filename = file as? String {
                result.append(filename)
            }
        }
        return result
    }
    
    private func validatePath(path: String?, creationDate: NSDate?, attemptIndex: Int, completionHandler: ((text: String?) -> ())) {
        if let path = path, creationDate = creationDate where buildCompletionDate == nil || buildCompletionDate?.compare(creationDate) == .OrderedAscending || buildCompletionDate?.compare(creationDate) == .OrderedSame {
            completionHandler(text: contentsOfFile(path))
            return
        } else if buildCompletionDate != nil {
            let attemptIndex = attemptIndex + 1
            if attemptIndex < retryAttempts {
                let delay = dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC))
                dispatch_after(delay, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                    self.logTextForProduct(attemptIndex, completionHandler: completionHandler)
                }
                return
            }
        }
        completionHandler(text: nil)
    }
    
    private func parseFiles(filenames: [String], buildFolderURL: NSURL, inout keyFilename: String?, inout creationDates: [String: NSDate]) {
        let activityLogExtension = ".xcactivitylog"
        for filename in filenames {
            if filename.hasSuffix(".db"),
                let path = buildFolderURL.URLByAppendingPathComponent(filename).path,
                let lastBuild = lastBuildKey(fromPath: path) {
                keyFilename = "\(lastBuild)\(activityLogExtension)"
            } else if filename.hasSuffix(activityLogExtension),
                let path = buildFolderURL.URLByAppendingPathComponent(filename).path,
                let creationDate = creationDateForFile(path) {
                creationDates[filename] = creationDate
            }
        }
    }
    
    private func lastBuildKey(fromPath path: String) -> String? {
        return lastDatabaseEntry(fromPath: path, usingFunction: { (key, value) -> String? in
            if let title = value["title"] as? String where title.hasPrefix("Build ") {
                return key
            }
            return nil
        })
    }
    
    private func lastSchemeName(fromPath path: String) -> String? {
        return lastDatabaseEntry(fromPath: path, usingFunction: { (key, value) -> String? in
            return value["schemeIdentifier-schemeName"] as? String
        })
    }
    
    private func lastDatabaseEntry(fromPath path: String, usingFunction f: (key: String, value: [String : AnyObject]) -> String?) -> String? {
        guard let data = NSDictionary(contentsOfFile: path)?["logs"] as? [String: AnyObject],
            let key = sortKeys(usingData: data).last?.key,
            let value = data[key] as? [String : AnyObject] else { return nil }
        
        return f(key: key, value: value)
    }
    
    private func sortKeys(usingData data: [String: AnyObject]) -> [(UInt, key: String)] {
        var sortedKeys: [(UInt, key: String)] = []
        for key in data.keys {
            if let value = data[key] as? [String: AnyObject],
                let timeStoppedRecording = value["timeStoppedRecording"] as? UInt {
                sortedKeys.append((timeStoppedRecording, key))
            }
        }
        return sortedKeys.sort{ $0.0 < $1.0 }
    }
    
    private func contentsOfFile(path: String) -> String? {
        if let data = NSData(contentsOfFile: path)?.gunzippedData() {
            return String(data: data, encoding: NSUTF8StringEncoding)
        }
        return nil
    }
    
    private func creationDateForFile(path: String) -> NSDate? {
        let fileAttributes = try? NSFileManager.defaultManager().attributesOfItemAtPath(path)
        return fileAttributes?[NSFileCreationDate] as? NSDate
    }
}

struct CMXcodeWorkSpace: CMXcodeWorkspaceProtocol {
    
    var retryAttempts = 10
    var productName: String
    var buildCompletionDate: NSDate?
    
    init(productName: String, buildCompletionDate: NSDate?) {
        self.productName = productName
        self.buildCompletionDate = buildCompletionDate
    }
}
