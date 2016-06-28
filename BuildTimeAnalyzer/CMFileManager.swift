//
//  CMFileManager.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 28/06/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Foundation

struct CMFile {
    let name: String
    let path: String
    let modificationDate: NSDate
}

class CMFileManager {
    
    // TODO: Replace with a cache
    static private let derivedDataLocation = "\(NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)[0])/Developer/Xcode/DerivedData"
    
    static func listCacheFiles() -> [CMFile] {
        let cacheFiles = getCacheFiles(at: NSURL(fileURLWithPath: derivedDataLocation))
        let earliestDate = NSDate().dateByAddingTimeInterval(-24 * 60 * 60)
        return filterFiles(cacheFiles, byEarliestDate: earliestDate)
    }
    
    static private func getCacheFiles(at url: NSURL) -> [CMFile] {
        let fileManager = NSFileManager.defaultManager()
        let keys = [NSURLNameKey, NSURLIsDirectoryKey]
        let options: NSDirectoryEnumerationOptions = [.SkipsHiddenFiles, .SkipsPackageDescendants, .SkipsSubdirectoryDescendants]
        
        guard let enumerator = fileManager.enumeratorAtURL(url, includingPropertiesForKeys: keys, options: options, errorHandler: nil) else { return [] }
        var result: [CMFile] = []
        for case let fileURL as NSURL in enumerator {
            if let cachePath = fileURL.URLByAppendingPathComponent("Logs/Build/Cache.db").path,
                let name = fileURL.lastPathComponent,
                let properties = try? fileManager.attributesOfItemAtPath(cachePath),
                let modificationDate = properties[NSFileModificationDate] as? NSDate {
                result.append(CMFile(name: name, path: cachePath, modificationDate: modificationDate))
            }
        }
        return result
    }
    
    static private func filterFiles(files: [CMFile], byEarliestDate date: NSDate) -> [CMFile] {
        guard files.count > 0 else { return [] }
        
        let sortedFiles = files.sort({ $0.modificationDate > $1.modificationDate })
        let recentFiles = sortedFiles.filter({ $0.modificationDate > date })
        if recentFiles.count == 0 {
            return [sortedFiles[0]]
        }
        return recentFiles
    }
}