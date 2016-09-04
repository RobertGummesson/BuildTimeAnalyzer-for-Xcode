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
    let modificationDate: Date
}

class CMFileManager {
    
    static fileprivate var _derivedDataLocation: String?
    static fileprivate let DerivedDataLocationKey = "DerivedDataLocationKey"
    
    static var derivedDataLocation: String {
        get {
            if _derivedDataLocation == nil {
                _derivedDataLocation = UserDefaults.standard.string(forKey: DerivedDataLocationKey)
            }
            if _derivedDataLocation == nil, let libraryFolder = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first {
                _derivedDataLocation = "\(libraryFolder)/Developer/Xcode/DerivedData"
            }
            return _derivedDataLocation ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: DerivedDataLocationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    static func listCacheFiles() -> [CMFile] {
        let cacheFiles = getCacheFiles(at: URL(fileURLWithPath: derivedDataLocation))
        let earliestDate = Date().addingTimeInterval(-24 * 60 * 60)
        return filterFiles(cacheFiles, byEarliestDate: earliestDate)
    }
    
    static fileprivate func getCacheFiles(at url: URL) -> [CMFile] {
        let fileManager = FileManager.default
        let keys = [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: options, errorHandler: nil) else { return [] }
        var result: [CMFile] = []
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            let cachePath = fileURL.appendingPathComponent("Logs/Build/Cache.db").path
            
            if let properties = try? fileManager.attributesOfItem(atPath: cachePath),
                let modificationDate = properties[FileAttributeKey.modificationDate] as? Date {
                result.append(CMFile(name: name, path: cachePath, modificationDate: modificationDate))
            }
        }
        return result
    }
    
    static fileprivate func filterFiles(_ files: [CMFile], byEarliestDate date: Date) -> [CMFile] {
        guard files.count > 0 else { return [] }
        
        let sortedFiles = files.sorted(by: { $0.modificationDate > $1.modificationDate })
        let recentFiles = sortedFiles.filter({ $0.modificationDate > date })
        if recentFiles.count == 0 {
            return [sortedFiles[0]]
        }
        return recentFiles
    }
}
