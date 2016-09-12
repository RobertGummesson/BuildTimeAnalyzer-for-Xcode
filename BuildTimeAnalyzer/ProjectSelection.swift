//
//  ProjectSelection.swift
//  BuildTimeAnalyzer
//

import Cocoa

protocol ProjectSelectionDelegate: class {
    func didSelectProject(with database: XcodeDatabase)
}

class ProjectSelection: NSObject {
    
    @IBOutlet weak var tableView: NSTableView!
    weak var delegate: ProjectSelectionDelegate?
    
    private var directoryMonitor: DirectoryMonitor?
    fileprivate var dataSource: [XcodeDatabase] = []
    
    static fileprivate let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .short
        dateFormatter.dateStyle = .medium
        return dateFormatter
    }()
    
    func startMonitoringDerivedData() {
        if directoryMonitor == nil {
            directoryMonitor = DirectoryMonitor(isDerivedData: true)
            directoryMonitor?.delegate = self
        }
        directoryMonitor?.startMonitoring(path: DerivedDataManager.derivedDataLocation)
    }
    
    func stopMonitoringDerivedData() {
        directoryMonitor?.stopMonitoring()
    }
    
    func listFolders() {
        dataSource =  DerivedDataManager.derivedData().flatMap{
            XcodeDatabase(fromPath: $0.url.appendingPathComponent("Logs/Build/Cache.db").path)
        }.filter{ $0.isBuildType }
        tableView.reloadData()
    }
    
    // MARK: Actions
    
    @IBAction func didSelectCell(_ sender: NSTableView) {
        delegate?.didSelectProject(with: dataSource[sender.selectedRow])
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
            value = source.schemeName
        default:
            value = ProjectSelection.dateFormatter.string(from: source.modificationDate)
        }
        cellView?.textField?.stringValue = value
        
        return cellView
    }
}

// MARK: DirectoryMonitorDelegate

extension ProjectSelection: DirectoryMonitorDelegate {
    func directoryMonitorDidObserveChange(_ directoryMonitor: DirectoryMonitor, isDerivedData: Bool) {
        listFolders()
    }
}
