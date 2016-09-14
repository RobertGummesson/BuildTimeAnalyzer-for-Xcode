//
//  DerivedDataManager.swift
//  BuildTimeAnalyzer
//

import Foundation

class DerivedDataManager {
    
    static func derivedData() -> [File] {
        let url = URL(fileURLWithPath: UserSettings.derivedDataLocation)
        
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
}
