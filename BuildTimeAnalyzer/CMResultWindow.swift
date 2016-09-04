//
//  CMResultWindowController.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Cocoa

class CMResultWindow: NSWindow {
    
    let IDEBuildOperationWillStartNotification              = "IDEBuildOperationWillStartNotification"
    let IDEBuildOperationDidGenerateOutputFilesNotification = "IDEBuildOperationDidGenerateOutputFilesNotification"
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var instructionsView: NSView!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var tableViewContainerView: NSScrollView!
    @IBOutlet weak var buildDurationTextField: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    
    fileprivate var dataSource: [CMCompileMeasure] = []
    fileprivate var filteredData: [CMCompileMeasure]? = nil
    fileprivate var processor: CMLogProcessor = CMLogProcessor()
    fileprivate var cacheFiles: [CMFile]?
    
    fileprivate var perFunctionTimes: [CMCompileMeasure] = []
    fileprivate var perFileTimes: [CMCompileMeasure] = []
    
    var processingState: CMProcessingState = .completed(stateName: CMProcessingState.completedString) {
        didSet {
            updateViewForState()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        guard self.cacheFiles == nil else { return }
        
        statusTextField.stringValue = CMProcessingState.waitingForBuildString
        
        let cacheFiles = CMFileManager.listCacheFiles()
        if let cacheFile = cacheFiles.first {
            processCacheFile(cacheFile)
        }
        self.cacheFiles = cacheFiles
    }
    
    func processCacheFile(_ cacheFile: CMFile) {
        processingState = .processing
        
        processor.processCacheFile(at: cacheFile.path) { [weak self] (result, didComplete) in
            guard let `self` = self else { return }
            
            self.dataSource = result
            self.perFunctionTimes = result
            self.perFileTimes = self.aggregateTimesByFile(self.perFunctionTimes)
            self.tableView.reloadData()
            
            if didComplete {
                let stateName = self.dataSource.isEmpty ? CMProcessingState.failedString : CMProcessingState.completedString
                self.processingState = .completed(stateName: stateName)
            }
        }
    }

    /*
     *  Aggregates all function times by file
     */
    func aggregateTimesByFile(_ functionTimes: [CMCompileMeasure]) -> [CMCompileMeasure] {
        var fileTimes = [String: CMCompileMeasure]()

        for measure in functionTimes {
            if var fileMeasure = fileTimes[measure.path] {
                // File exists, increment time
                fileMeasure.time += measure.time
                fileTimes[measure.path] = fileMeasure
            } else {
                let newFileMeasure = CMCompileMeasure(rawPath: measure.path, time: measure.time)
                fileTimes[measure.path] = newFileMeasure
            }
        }
        // Sort by time
        return Array(fileTimes.values).sorted(by: { $0.time > $1.time })
    }
    
    func updateViewForState() {
        switch processingState {
        case .processing:
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(self)
            statusTextField.stringValue = CMProcessingState.processingString
            showInstructions(false)
            cancelButton.isHidden = false
            
        case .completed(let stateName):
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = stateName
            showInstructions(stateName == CMProcessingState.failedString)
            progressIndicator.isHidden = true
            cancelButton.isHidden = true
            
        case .waiting(let shouldIndicate):
            if shouldIndicate {
                progressIndicator.startAnimation(self)
                statusTextField.stringValue = CMProcessingState.buildString
                showInstructions(false)
            } else {
                progressIndicator.stopAnimation(self)
                statusTextField.stringValue = CMProcessingState.waitingForBuildString
            }
            progressIndicator.isHidden = !shouldIndicate
            cancelButton.isHidden = true
        }
        searchField.isHidden = !cancelButton.isHidden
    }
    
    func showInstructions(_ show: Bool) {
        instructionsView.isHidden = !show
        progressIndicator.isHidden = show
        tableViewContainerView.isHidden = show
    }

    // MARK: Actions
    
    @IBAction func perFileCheckboxClicked(_ sender: NSButton) {
        dataSource = sender.state == 0 ? perFunctionTimes : perFileTimes
        tableView.reloadData()
    }

    @IBAction func clipboardButtonClicked(_ sender: AnyObject) {
        NSPasteboard.general().clearContents()
        NSPasteboard.general().writeObjects(["-Xfrontend -debug-time-function-bodies" as NSPasteboardWriting])
    }
    
    @IBAction func cancelButtonClicked(_ sender: AnyObject) {
        processor.shouldCancel = true
    }
    
    override func controlTextDidChange(_ obj: Notification) {
		guard let field = obj.object as? NSSearchField , field == searchField else { return }
        
        filteredData = field.stringValue.isEmpty ? nil : dataSource.filter{ textContains($0.code) || textContains($0.filename) }
		tableView.reloadData()
	}

    func textContains(_ text: String) -> Bool {
        return text.lowercased().contains(searchField.stringValue.lowercased())
    }
}

extension CMResultWindow: NSTableViewDataSource {
	func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredData?.count ?? dataSource.count
	}
}

extension CMResultWindow: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, let columnIndex = tableView.tableColumns.index(of: tableColumn) else { return nil }
        
        let result = tableView.make(withIdentifier: "Cell\(columnIndex)", owner: self) as? NSTableCellView
        result?.textField?.stringValue = filteredData?[row][columnIndex] ?? dataSource[row][columnIndex]
        
        return result
    }
    
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let item = filteredData?[row] ?? dataSource[row]
        _ = NSApp.delegate?.application?(NSApp, openFile: item.path)
        
		return true
	}
}

extension CMResultWindow: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        processor.shouldCancel = true
//        processingState = .completed(stateName: CMProcessingState.cancelledString)
//        removeObservers()
    }
}
