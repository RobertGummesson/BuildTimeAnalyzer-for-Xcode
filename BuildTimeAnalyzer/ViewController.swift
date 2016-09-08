//
//  ViewController.swift
//  BuildTimeAnalyzer
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var instructionsView: NSView!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var tableViewContainerView: NSScrollView!
    @IBOutlet weak var derivedDataTextField: NSTextField!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var perFileButton: NSButton!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var projectSelection: ProjectSelection!
    
    fileprivate var dataSource: [CompileMeasure] = []
    fileprivate var filteredData: [CompileMeasure]?
    fileprivate var canUpdateViewForState = true
    
    private var processor = LogProcessor()
    private var perFunctionTimes: [CompileMeasure] = []
    private var perFileTimes: [CompileMeasure] = []
    
    var processingState: ProcessingState = .waiting(shouldIndicate: false) {
        didSet {
            updateViewForState()
        }
    }
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureLayout()
        
        projectSelection.listFolders()
        projectSelection.startMonitoringDerivedData()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        
        processor.shouldCancel = true
        NSApp.terminate(self)
    }
    
    // MARK: Layout
    
    func configureLayout() {
        derivedDataTextField.stringValue = DerivedDataManager.derivedDataLocation
        updateViewForState()
        showInstructions(true)
    }
    
    func showInstructions(_ show: Bool) {
        instructionsView.isHidden = !show
        
        perFileButton.isHidden = show
        searchField.isHidden = show
        statusLabel.isHidden = show
        statusTextField.isHidden = show
        tableViewContainerView.isHidden = show
        
        if show && processingState == .processing {
            processor.shouldCancel = true
            cancelButton.isHidden = true
        }
    }
    
    func aggregateTimesByFile(_ functionTimes: [CompileMeasure]) -> [CompileMeasure] {
        var fileTimes = [String: CompileMeasure]()
        
        for measure in functionTimes {
            if var fileMeasure = fileTimes[measure.path] {
                // File exists, increment time
                fileMeasure.time += measure.time
                fileTimes[measure.path] = fileMeasure
            } else {
                let newFileMeasure = CompileMeasure(rawPath: measure.path, time: measure.time)
                fileTimes[measure.path] = newFileMeasure
            }
        }
        // Sort by time
        return Array(fileTimes.values).sorted{ $0.time > $1.time }
    }
    
    func updateViewForState() {
        guard canUpdateViewForState else { return }
        
        switch processingState {
        case .processing:
            showInstructions(false)
            progressIndicator.isHidden = false
            progressIndicator.startAnimation(self)
            statusTextField.stringValue = ProcessingState.processingString
            cancelButton.isHidden = false
            
        case .completed(_, let stateName):
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = stateName
            progressIndicator.isHidden = true
            cancelButton.isHidden = true
            
        case .waiting(let shouldIndicate):
            if shouldIndicate {
                progressIndicator.startAnimation(self)
                statusTextField.stringValue = ProcessingState.buildString
                showInstructions(false)
            } else {
                progressIndicator.stopAnimation(self)
                statusTextField.stringValue = ProcessingState.waitingForBuildString
            }
            progressIndicator.isHidden = !shouldIndicate
            cancelButton.isHidden = true
        }
        
        if instructionsView.isHidden {
            searchField.isHidden = !cancelButton.isHidden
        }
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
        if let field = obj.object as? NSSearchField, field == searchField {
            filteredData = field.stringValue.isEmpty ? nil : dataSource.filter{ textContains($0.code) || textContains($0.filename) }
            tableView.reloadData()
        } else if let field = obj.object as? NSTextField, field == derivedDataTextField {
            projectSelection.stopMonitoringDerivedData()
            
            DerivedDataManager.derivedDataLocation = field.stringValue
            
            projectSelection.listFolders()
            projectSelection.startMonitoringDerivedData()
        }
    }
    
    func cancelProcessing() {
        guard processingState == .processing else { return }
        
        processor.shouldCancel = true
        cancelButton.isHidden = true
        canUpdateViewForState = false
    }
    
    // MARK: Utilities
    
    func configureMenuItems(showBuildTimesMenuItem: Bool) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.configureMenuItems(showBuildTimesMenuItem: showBuildTimesMenuItem)
        }
    }
    
    func processFile(at url: URL) {
        processingState = .processing
        
        processor.processCacheFile(at: url.path) { [weak self] (result, didComplete) in
            guard let `self` = self else { return }
            
            self.dataSource = result
            self.perFunctionTimes = result
            self.perFileTimes = self.aggregateTimesByFile(self.perFunctionTimes)
            self.tableView.reloadData()
            
            if didComplete {
                let didSucceed = !self.dataSource.isEmpty
                let stateName = didSucceed ? ProcessingState.completedString : ProcessingState.failedString
                self.processingState = .completed(didSucceed: didSucceed, stateName: stateName)
                
                if !didSucceed {
                    NSAlert.show(withMessage: ProcessingState.failedString)
                    
                    self.showInstructions(true)
                    self.configureMenuItems(showBuildTimesMenuItem: true)
                }
            }
        }
    }
    
    func textContains(_ text: String) -> Bool {
        return text.lowercased().contains(searchField.stringValue.lowercased())
    }
}

// MARK: NSTableViewDataSource

extension ViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredData?.count ?? dataSource.count
    }
}

// MARK: NSTableViewDelegate

extension ViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, let columnIndex = tableView.tableColumns.index(of: tableColumn) else { return nil }
        
        let result = tableView.make(withIdentifier: "Cell\(columnIndex)", owner: self) as? NSTableCellView
        result?.textField?.stringValue = filteredData?[row][columnIndex] ?? dataSource[row][columnIndex]
        
        return result
    }
}

// MARK: ProjectSelectionDelegate

extension ViewController: ProjectSelectionDelegate {
    func didSelectProject(with url: URL) {
        canUpdateViewForState = true
        
        configureMenuItems(showBuildTimesMenuItem: false)        
        processFile(at: url.appendingPathComponent("Logs/Build/Cache.db"))
    }
}
