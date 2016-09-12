//
//  DerivedDataManager.swift
//  BuildTimeAnalyzer
//

import Foundation

class DerivedDataManager {
    
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
            _derivedDataLocation = newValue
            UserDefaults.standard.set(newValue, forKey: DerivedDataLocationKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    static func derivedData() -> [File] {
        let url = URL(fileURLWithPath: derivedDataLocation)
        
        let folders = DerivedDataManager.listFolders(at: url)
        let fileManager = FileManager.default
        
        return folders.flatMap{ (url) -> File? in
            if url.lastPathComponent != "ModuleCache",
                let properties = try? fileManager.attributesOfItem(atPath: url.path),
                let modificationDate = properties[FileAttributeKey.modificationDate] as? Date {
                return File(date: modificationDate, url: url)
            }
            return nil
        }.sorted{ $0.date > $1.date }
    }
    
    static func listFolders(at url: URL) -> [URL] {
        let fileManager = FileManager.default
        let keys = [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: options, errorHandler: nil) else { return [] }
        
        return enumerator.map{ $0 as! URL }
    }
    
    static func listCacheFiles() -> [CacheFile] {
        let files = cacheFiles(at: URL(fileURLWithPath: derivedDataLocation))
        let earliestDate = Date().addingTimeInterval(-24 * 60 * 60)
        return filterFiles(files, byEarliestDate: earliestDate)
    }
    
    static private func cacheFiles(at url: URL) -> [CacheFile] {
        let fileManager = FileManager.default
        let keys = [URLResourceKey.nameKey, URLResourceKey.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]
        
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: keys, options: options, errorHandler: nil) else { return [] }
        
        var result: [CacheFile] = []
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent
            let cachePath = fileURL.appendingPathComponent("Logs/Build/Cache.db").path
            
            if let properties = try? fileManager.attributesOfItem(atPath: cachePath),
                let modificationDate = properties[FileAttributeKey.modificationDate] as? Date {
                result.append(CacheFile(name: name, path: cachePath, modificationDate: modificationDate))
            }
        }
        return result
    }
    
    static private func filterFiles(_ files: [CacheFile], byEarliestDate date: Date) -> [CacheFile] {
        guard files.count > 0 else { return [] }
        
        let sortedFiles = files.sorted(by: { $0.modificationDate > $1.modificationDate })
        let recentFiles = sortedFiles.filter({ $0.modificationDate > date })
        if recentFiles.count == 0 {
            return [sortedFiles[0]]
        }
        return recentFiles
    }
}
