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
    
    private var dataSource: [CMCompileMeasure] = []
    private var filteredData: [CMCompileMeasure]? = nil
    private var processor: CMLogProcessor = CMLogProcessor()
    private var cacheFiles: [CMFile]?
    
    private var perFunctionTimes: [CMCompileMeasure] = []
    private var perFileTimes: [CMCompileMeasure] = []
    
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
    
    func processCacheFile(cacheFile: CMFile) {
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
    func aggregateTimesByFile(functionTimes: [CMCompileMeasure]) -> [CMCompileMeasure] {
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
        return Array(fileTimes.values).sort({ $0.time > $1.time })
    }
    
    func updateViewForState() {
        switch processingState {
        case .processing:
            progressIndicator.hidden = false
            progressIndicator.startAnimation(self)
            statusTextField.stringValue = CMProcessingState.processingString
            showInstructions(false)
            cancelButton.hidden = false
            
        case .completed(let stateName):
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = stateName
            showInstructions(stateName == CMProcessingState.failedString)
            progressIndicator.hidden = true
            cancelButton.hidden = true
            
        case .waiting(let shouldIndicate):
            if shouldIndicate {
                progressIndicator.startAnimation(self)
                statusTextField.stringValue = CMProcessingState.buildString
                showInstructions(false)
            } else {
                progressIndicator.stopAnimation(self)
                statusTextField.stringValue = CMProcessingState.waitingForBuildString
            }
            progressIndicator.hidden = !shouldIndicate
            cancelButton.hidden = true
        }
        searchField.hidden = !cancelButton.hidden
    }
    
    func showInstructions(show: Bool) {
        instructionsView.hidden = !show
        progressIndicator.hidden = show
        tableViewContainerView.hidden = show
    }

    // MARK: Actions
    
    @IBAction func perFileCheckboxClicked(sender: NSButton) {
        if sender.state == 0 {
            self.dataSource = self.perFunctionTimes
        } else {
            self.dataSource = self.perFileTimes
        }
        self.tableView.reloadData()
    }

    @IBAction func clipboardButtonClicked(sender: AnyObject) {
        NSPasteboard.generalPasteboard().clearContents()
        NSPasteboard.generalPasteboard().writeObjects(["-Xfrontend -debug-time-function-bodies"])
    }
    
    @IBAction func cancelButtonClicked(sender: AnyObject) {
        processor.shouldCancel = true
    }
    
    override func controlTextDidChange(obj: NSNotification) {
		guard let field = obj.object as? NSSearchField where field == searchField else { return }
        
        filteredData = field.stringValue.isEmpty ? nil : dataSource.filter{ textContains($0.code) || textContains($0.filename) }
		tableView.reloadData()
	}

    func textContains(text: String) -> Bool {
        return text.lowercaseString.containsString(searchField.stringValue.lowercaseString)
    }
}

extension CMResultWindow: NSTableViewDataSource {
	func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return filteredData?.count ?? dataSource.count
	}
}

extension CMResultWindow: NSTableViewDelegate {

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, columnIndex = tableView.tableColumns.indexOf(tableColumn) else { return nil }
        
        let result = tableView.makeViewWithIdentifier("Cell\(columnIndex)", owner: self) as? NSTableCellView
        result?.textField?.stringValue = filteredData?[row][columnIndex] ?? dataSource[row][columnIndex]
        
        return result
    }
    
	func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let item = filteredData?[row] ?? dataSource[row]
        NSApp.delegate?.application?(NSApp, openFile: item.path)
        
		return true
	}
}

extension CMResultWindow: NSWindowDelegate {
    
    func windowWillClose(notification: NSNotification) {
        processor.shouldCancel = true
//        processingState = .completed(stateName: CMProcessingState.cancelledString)
//        removeObservers()
    }
}
