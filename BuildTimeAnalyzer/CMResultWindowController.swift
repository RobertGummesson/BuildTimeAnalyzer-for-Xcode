//
//  CMResultWindowController.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import Cocoa

class CMResultWindowController: NSWindowController {
    
    let IDEBuildOperationWillStartNotification              = "IDEBuildOperationWillStartNotification"
    let IDEBuildOperationDidGenerateOutputFilesNotification = "IDEBuildOperationDidGenerateOutputFilesNotification"
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var instructionsView: NSView!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var resultWindow: NSWindow!
    @IBOutlet weak var tableViewContainerView: NSScrollView!
    @IBOutlet weak var buildDurationTextField: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    
    var dataSource: [CMCompileMeasure] = []
    var processor: CMLogProcessor = CMLogProcessor()
    
    var buildOperationWillStartObserver: AnyObject?
    var buildOperationDidGenerateOutputFilesObserver: AnyObject?
    
    var processingState: CMProcessingState = .completed(stateName: CMProcessingState.completedString) {
        didSet {
            updateViewForState()
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        statusTextField.stringValue = CMProcessingState.waitingForBuildString
    }
    
    deinit {
        removeObservers()
    }
    
    func show() {
        showWindow(self)
        addObservers()
        
        // Get currentProduct needs to be run before resultWindow.makeMainWindow()
        if let currentProduct = CMXcodeWorkSpace.currentProductName() {
            processLog(currentProduct)
        }
        
        if let window = resultWindow {
            window.makeMainWindow()
            window.level = Int(CGWindowLevelKey.OverlayWindowLevelKey.rawValue)
            updateViewForState()
        }
    }
    
    func processLog(productName: String, buildCompletionDate: NSDate? = nil) {
        guard processingState != .processing else { return }
        processingState = .processing
        
        dataSource.removeAll()
        tableView.reloadData()
        
        processor.process(productName, buildCompletionDate: buildCompletionDate, updateHandler: { [weak self] (result, didComplete) in
            guard let strongSelf = self else { return }
            
            strongSelf.dataSource = result
            strongSelf.tableView.reloadData()
            
            if didComplete {
                let stateName = strongSelf.dataSource.isEmpty ? CMProcessingState.failedString : CMProcessingState.completedString
                strongSelf.processingState = .completed(stateName: stateName)
            }
        })
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
            cancelButton.hidden = true
        }
    }
    
    func showInstructions(show: Bool) {
        instructionsView.hidden = !show
        progressIndicator.hidden = show
        tableViewContainerView.hidden = show
    }
    
    // MARK: Actions
    
    @IBAction func clipboardButtonClicked(sender: AnyObject) {
        NSPasteboard.generalPasteboard().clearContents()
        NSPasteboard.generalPasteboard().writeObjects(["-Xfrontend -debug-time-function-bodies"])
    }
    
    @IBAction func cancelButtonClicked(sender: AnyObject) {
        processor.shouldCancel = true
    }
    // MARK: Observers
    
    func addObservers() {
        buildOperationWillStartObserver = NSNotificationCenter.addObserverForName(IDEBuildOperationWillStartNotification, usingBlock: { [weak self] (note) in
            if let stateDescription = note.object?.valueForKeyPath("_buildStatus._stateDescription") as? String {
                self?.processingState = .waiting(shouldIndicate: stateDescription == "Build")
            }
        })
        
        buildOperationDidGenerateOutputFilesObserver = NSNotificationCenter.addObserverForName(IDEBuildOperationDidGenerateOutputFilesNotification, usingBlock: { [weak self] (note) in
            guard let buildOperation = CMXcodeWorkSpace.buildOperation(fromData: note.object) else { return  }
            
            if buildOperation.result == 1 && buildOperation.actionName == "Build" {
                self?.buildDurationTextField.stringValue = String(format: "%.0fs", round(buildOperation.duration))
                self?.processLog(buildOperation.productName, buildCompletionDate: buildOperation.endTime)
            } else {
                self?.processingState = .waiting(shouldIndicate: false)
            }
        })
    }
    
    func removeObservers() {
        NSNotificationCenter.removeObserver(buildOperationWillStartObserver, name: IDEBuildOperationWillStartNotification)
        NSNotificationCenter.removeObserver(buildOperationDidGenerateOutputFilesObserver, name: IDEBuildOperationWillStartNotification)
    }
}

extension CMResultWindowController: NSTableViewDataSource {
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return dataSource.count
    }
}

extension CMResultWindowController: NSTableViewDelegate {

    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, columnIndex = tableView.tableColumns.indexOf(tableColumn) else { return nil }
        
        let result = tableView.makeViewWithIdentifier("Cell\(columnIndex)", owner: self) as? NSTableCellView
        result?.textField?.stringValue = dataSource[row][columnIndex]
        
        return result
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let item = dataSource[row]
        processor.workspace?.openFile(atPath: item.path, andLineNumber: item.location, focusLostHandler: { [weak self] in
            self?.resultWindow.makeKeyWindow()
        })
        return true
    }
}

extension CMResultWindowController: NSWindowDelegate {
    
    func windowWillClose(notification: NSNotification) {
        processor.shouldCancel = true
        processingState = .completed(stateName: CMProcessingState.cancelledString)
        removeObservers()
    }
}
