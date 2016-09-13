//
//  BuildManager.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 12/09/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Cocoa

protocol BuildManagerDelegate: class {
    func derivedDataDidChange()
    func buildManager(_ buildManager: BuildManager, shouldParseLogWithDatabase database: XcodeDatabase)
}

class BuildManager: NSObject {
    
    weak var delegate: BuildManagerDelegate?
    
    private let derivedDataDirectoryMonitor = DirectoryMonitor(isDerivedData: true)
    private let logFolderDirectoryMonitor = DirectoryMonitor(isDerivedData: false)
    
    private var currentDataBase: XcodeDatabase?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        derivedDataDirectoryMonitor.delegate = self
        logFolderDirectoryMonitor.delegate = self
        
        startMonitoring()
    }
    
    func startMonitoring() {
        stopMonitoring()
        derivedDataDirectoryMonitor.startMonitoring(path: DerivedDataManager.derivedDataLocation)
    }
    
    func stopMonitoring() {
        derivedDataDirectoryMonitor.stopMonitoring()
    }
    
    func database(forFolder URL: URL) -> XcodeDatabase? {
        let databaseURL = URL.appendingPathComponent("Cache.db")
        return XcodeDatabase(fromPath: databaseURL.path)
    }
    
    func processDerivedData() {
        guard let mostRecent = DerivedDataManager.derivedData().first else { return }
        
        let logFolder = mostRecent.url.appendingPathComponent("Logs/Build").path
        guard logFolderDirectoryMonitor.path != logFolder else { return }
        
        logFolderDirectoryMonitor.stopMonitoring()
        logFolderDirectoryMonitor.startMonitoring(path: logFolder)
    }
    
    func processLogFolder(with url: URL) {
        guard let activeDatabase = database(forFolder: url),
            activeDatabase.isBuildType,
            activeDatabase != currentDataBase else { return }
        
        currentDataBase = activeDatabase
        delegate?.buildManager(self, shouldParseLogWithDatabase: activeDatabase)
    }
}

extension BuildManager: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(_ directoryMonitor: DirectoryMonitor, isDerivedData: Bool) {
        if isDerivedData {
            delegate?.derivedDataDidChange()
            processDerivedData()
        } else if let path = directoryMonitor.path {
            // TODO: If we don't dispatch, it seems it fires off too soon
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.processLogFolder(with: URL(fileURLWithPath: path))
            }
        }
    }
}
