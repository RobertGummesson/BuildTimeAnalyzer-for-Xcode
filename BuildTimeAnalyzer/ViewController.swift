//
//  ViewController.swift
//  BuildTimeAnalyzer
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet var buildManager: BuildManager!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var derivedDataTextField: NSTextField!
    @IBOutlet weak var instructionsView: NSView!
    @IBOutlet weak var perFileButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var projectSelection: ProjectSelection!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewContainerView: NSScrollView!
    @IBOutlet weak var leftButton: NSButton!
    
    fileprivate var dataSource: [CompileMeasure] = []
    fileprivate var filteredData: [CompileMeasure]?
    fileprivate var canUpdateViewForState = true
    
    private var currentKey: String?
    private var nextDatabase: XcodeDatabase?
    
    private var processor = LogProcessor()
    private var perFunctionTimes: [CompileMeasure] = []
    private var perFileTimes: [CompileMeasure] = []
    
    var processingState: ProcessingState = .waiting() {
        didSet {
            updateViewForState()
        }
    }
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureLayout()
        
        buildManager.delegate = self
        projectSelection.delegate = self
        
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
        
        leftButton.isHidden = show
        perFileButton.isHidden = show
        searchField.isHidden = show
        statusLabel.isHidden = show
        statusTextField.isHidden = show
        tableViewContainerView.isHidden = show
        
        if show && processingState == .processing {
            processor.shouldCancel = true
            cancelButton.isHidden = true
            progressIndicator.isHidden = true
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
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = stateName
            cancelButton.isHidden = true
            
        case .waiting():
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = ProcessingState.waitingForBuildString
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
    
    @IBAction func leftButtonClicked(_ sender: NSButton) {
        configureMenuItems(showBuildTimesMenuItem: false)
        
        cancelProcessing()
        showInstructions(true)
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
    
    // MARK: Utilities
    
    func cancelProcessing() {
        guard processingState == .processing else { return }
        
        processor.shouldCancel = true
        cancelButton.isHidden = true
        canUpdateViewForState = false
    }
    
    func configureMenuItems(showBuildTimesMenuItem: Bool) {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.configureMenuItems(showBuildTimesMenuItem: showBuildTimesMenuItem)
        }
    }
    
    func processLog(with database: XcodeDatabase) {
        guard processingState != .processing else {
            if let currentKey = currentKey, currentKey != database.key {
                nextDatabase = database
                processor.shouldCancel = true
            }
            return
        }
        
        canUpdateViewForState = true
        configureMenuItems(showBuildTimesMenuItem: false)
        NSLog("Starting \(database.key)")
        
        processingState = .processing
        currentKey = database.key
        
        processor.processDatabase(database: database) { [weak self] (result, didComplete) in
            self?.handleProcessorUpdate(result: result, didComplete: didComplete)
        }
    }
    
    func handleProcessorUpdate(result: [CompileMeasure], didComplete: Bool) {
        dataSource = result
        perFunctionTimes = result
        perFileTimes = aggregateTimesByFile(perFunctionTimes)
        tableView.reloadData()
        
        if didComplete {
            completeProcessorUpdate()
        }
    }
    
    func completeProcessorUpdate() {
        let didSucceed = !dataSource.isEmpty
        let stateName = didSucceed ? ProcessingState.completedString : ProcessingState.failedString
        
        processingState = .completed(didSucceed: didSucceed, stateName: stateName)
        currentKey = nil
        
        if let nextDatabase = nextDatabase {
            self.nextDatabase = nil
            processLog(with: nextDatabase)
        }
        
        if !didSucceed {
            let text = "Ensure the Swift compiler flags has been added."
            NSAlert.show(withMessage: ProcessingState.failedString, andInformativeText: text)
            
            showInstructions(true)
            configureMenuItems(showBuildTimesMenuItem: true)
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
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let item = filteredData?[row] ?? dataSource[row]
        NSWorkspace.shared().openFile(item.path)
        
        return true
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

// MARK: BuildManagerDelegate 

extension ViewController: BuildManagerDelegate {
    func buildManager(_ buildManager: BuildManager, shouldParseLogWithDatabase database: XcodeDatabase) {
        processLog(with: database)
    }
}

// MARK: ProjectSelectionDelegate

extension ViewController: ProjectSelectionDelegate {
    func didSelectProject(with database: XcodeDatabase) {
        processLog(with: database)
    }
}
