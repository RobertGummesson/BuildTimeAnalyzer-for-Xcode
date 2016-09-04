//
//  ProjectSelection.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 04/09/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Cocoa

@objc protocol ProjectSelectionDelegate: class {
    func didSelectProject(with url: URL)
}

class ProjectSelection: NSObject {
    
    typealias SourceType = (date: Date, url: URL)
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var delegate: ProjectSelectionDelegate?
    
    private var directoryMonitor: DirectoryMonitor?
    fileprivate var dataSource: [SourceType] = []
    
    func startMonitoringDerivedData() {
        if directoryMonitor == nil {
            directoryMonitor = DirectoryMonitor(path: DerivedDataManager.derivedDataLocation)
            directoryMonitor?.delegate = self
        }
        directoryMonitor?.startMonitoring()
    }
    
    func stopMonitoringDerivedData() {
        directoryMonitor?.stopMonitoring()
    }
    
    func listFolders() {
        let url = URL(fileURLWithPath: DerivedDataManager.derivedDataLocation)
        

        let folders = DerivedDataManager.listFolders(at: url)
        let fileManager = FileManager.default
        
        dataSource = folders.flatMap{ (url) -> SourceType? in
            if let properties = try? fileManager.attributesOfItem(atPath: url.path),
                let modificationDate = properties[FileAttributeKey.modificationDate] as? Date {
                return SourceType(date: modificationDate, url: url)
            }
            return nil
        }.sorted{ $0.date > $1.date }
        tableView.reloadData()
    }
}

// MARK: NSTableViewDataSource

extension ProjectSelection: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return dataSource.count
    }
}

// MARK: NSTableViewDelegate

extension ProjectSelection: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, let columnIndex = tableView.tableColumns.index(of: tableColumn) else { return nil }
        
        let cellView = tableView.make(withIdentifier: "Cell\(columnIndex)", owner: self) as? NSTableCellView
        
        let source = dataSource[row]
        var value = ""
        
        switch columnIndex {
        case 0:
            value = source.url.lastPathComponent
        default:
            value = source.date.description
        }
        cellView?.textField?.stringValue = value
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        delegate?.didSelectProject(with: dataSource[row].url)
        
        return true
    }
}

// MARK: DirectoryMonitorDelegate

extension ProjectSelection: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(_ directoryMonitor: DirectoryMonitor) {
        listFolders()
    }
}
