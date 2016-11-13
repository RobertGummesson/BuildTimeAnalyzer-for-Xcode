//
//  ViewController.swift
//  BuildTimeAnalyzer
//

import Cocoa
class ViewController: NSViewController {
    
    @IBOutlet var buildManager: BuildManager!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var compileTimeTextField: NSTextField!
    @IBOutlet weak var derivedDataTextField: NSTextField!
    @IBOutlet weak var instructionsView: NSView!
    @IBOutlet weak var leftButton: NSButton!
    @IBOutlet weak var perFileButton: NSButton!
    @IBOutlet weak var addCommentButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var projectSelection: ProjectSelection!
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var statusTextField: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var tableViewContainerView: NSScrollView!
    
    fileprivate var dataSource: [CompileMeasure] = []
    fileprivate var filteredData: [CompileMeasure]?
    
    private var currentKey: String?
    private var nextDatabase: XcodeDatabase?
    
    private var processor = LogProcessor()
    private var perFunctionTimes: [CompileMeasure] = []
    private var perFileTimes: [CompileMeasure] = []
    
    fileprivate var canAddCommentWhenClick: Bool = false

    let NEW_LINE_DELIMITER = "NEW_LINE_DELIMITER"
    var processingState: ProcessingState = .waiting {
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose(notification:)), name: .NSWindowWillClose, object: nil)
    }
    
    func windowWillClose(notification: NSNotification) {
        guard let object = notification.object, !(object is NSPanel) else { return }
        NotificationCenter.default.removeObserver(self)
        
        processor.shouldCancel = true
        NSApp.terminate(self)
    }
    
    // MARK: Layout
    
    func configureLayout() {
        updateTotalLabel(with: 0)
        updateViewForState()
        showInstructions(true)
        
        derivedDataTextField.stringValue = UserSettings.derivedDataLocation
        makeWindowTopMost(topMost: UserSettings.windowShouldBeTopMost)
    }
    
    func showInstructions(_ show: Bool) {
        instructionsView.isHidden = !show
        
        let views: [NSView] = [compileTimeTextField, leftButton, perFileButton, searchField, statusLabel, statusTextField, tableViewContainerView,addCommentButton]
        views.forEach{ $0.isHidden = show }
        
        if show && processingState == .processing {
            processor.shouldCancel = true
            cancelButton.isHidden = true
            progressIndicator.isHidden = true
        }
    }
    
    func aggregateTimesByFile(_ functionTimes: [CompileMeasure]) -> [CompileMeasure] {
        var fileTimes: [String: CompileMeasure] = [:]
        
        for measure in functionTimes {
            if var fileMeasure = fileTimes[measure.path] {
                fileMeasure.time += measure.time
                fileTimes[measure.path] = fileMeasure
            } else {
                let newFileMeasure = CompileMeasure(rawPath: measure.path, time: measure.time)
                fileTimes[measure.path] = newFileMeasure
            }
        }
        return Array(fileTimes.values).sorted{ $0.time > $1.time }
    }
    
    func updateViewForState() {
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
            
        case .waiting:
            progressIndicator.isHidden = true
            progressIndicator.stopAnimation(self)
            statusTextField.stringValue = ProcessingState.waitingForBuildString
            cancelButton.isHidden = true
        }
        
        if instructionsView.isHidden {
            searchField.isHidden = !cancelButton.isHidden
        }
    }
    
    func makeWindowTopMost(topMost: Bool) {
        if let window = NSApplication.shared().windows.first {
            let level: CGWindowLevelKey = topMost ? .floatingWindow : .normalWindow
            window.level = Int(CGWindowLevelForKey(level))
        }
    }
    
    // MARK: Actions
    
    @IBAction func perFileCheckboxClicked(_ sender: NSButton) {
        dataSource = sender.state == 0 ? perFunctionTimes : perFileTimes
        tableView.reloadData()
    }

    @IBAction func addCommentWhenClick(_ sender: NSButton) {
        
        canAddCommentWhenClick = !canAddCommentWhenClick
    }
    
    @IBAction func clipboardButtonClicked(_ sender: AnyObject) {
        NSPasteboard.general().clearContents()
        NSPasteboard.general().writeObjects(["-Xfrontend -debug-time-function-bodies" as NSPasteboardWriting])
    }
    
    @IBAction func visitDerivedData(_ sender: AnyObject) {
        
        let path = self.derivedDataTextField.stringValue
        
        NSWorkspace.shared().openFile(path)
        
    }
    
    
    @IBAction func cancelButtonClicked(_ sender: AnyObject) {
        processor.shouldCancel = true
    }
    
    @IBAction func leftButtonClicked(_ sender: NSButton) {
        configureMenuItems(showBuildTimesMenuItem: true)
        
        cancelProcessing()
        showInstructions(true)
        projectSelection.listFolders()
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSSearchField, field == searchField {
            filteredData = field.stringValue.isEmpty ? nil : dataSource.filter{ textContains($0.code) || textContains($0.filename) }
            tableView.reloadData()
        } else if let field = obj.object as? NSTextField, field == derivedDataTextField {
            buildManager.stopMonitoring()
            UserSettings.derivedDataLocation = field.stringValue
            
            projectSelection.listFolders()
            buildManager.startMonitoring()
        }
    }
    
    // MARK: Utilities
    
    func cancelProcessing() {
        guard processingState == .processing else { return }
        
        processor.shouldCancel = true
        cancelButton.isHidden = true
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
        
        configureMenuItems(showBuildTimesMenuItem: false)
        
        processingState = .processing
        currentKey = database.key
        
        updateTotalLabel(with: database.buildTime)
        
        processor.processDatabase(database: database) { [weak self] (result, didComplete, didCancel) in
            self?.handleProcessorUpdate(result: result, didComplete: didComplete, didCancel: didCancel)
        }
    }
    
    func handleProcessorUpdate(result: [CompileMeasure], didComplete: Bool, didCancel: Bool) {
        dataSource = result
        perFunctionTimes = result
        perFileTimes = aggregateTimesByFile(perFunctionTimes)
        tableView.reloadData()
        
        if didComplete {
            completeProcessorUpdate(didCancel: didCancel)
        }
    }
    
    func completeProcessorUpdate(didCancel: Bool) {
        let didSucceed = !dataSource.isEmpty
        
        var stateName = ProcessingState.failedString
        if didCancel {
            stateName = ProcessingState.cancelledString
        } else if didSucceed {
            stateName = ProcessingState.completedString
        }
        
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
    
    func updateTotalLabel(with buildTime: Int) {
        let text = "Build duration: " + (buildTime < 60 ? "\(buildTime)s" : "\(buildTime / 60)m \(buildTime % 60)s")
        compileTimeTextField.stringValue = text
    }
    
    func textContains(_ text: String) -> Bool {
        return text.lowercased().contains(searchField.stringValue.lowercased())
    }
    
    func writeTo(filePath:String,comment:String,lineNumber:Int) {
        
        
        // use NSUTF8StringEncoding to read UTF-8 text
        do{
            
            var multiLineString =  try String(contentsOfFile: filePath, encoding:  String.Encoding.utf8)
            
            
             multiLineString = multiLineString.replacingOccurrences(of: "\r\n", with: "\r\n\(NEW_LINE_DELIMITER)")

            
            
            //let newlineChars = NSCharacterSet.newlines
            //var lineArray = multiLineString.components(separatedBy: newlineChars)

            var lineArray = multiLineString.components(separatedBy: "\r\n") // ["Hello", "World"]
            lineArray.insert(comment, at: lineNumber)
            
            multiLineString = lineArray.joined(separator:  "")
            multiLineString = multiLineString.replacingOccurrences(of: "NEW_LINE_DELIMITER", with: "\r\n")
            try? multiLineString.write(toFile: filePath, atomically: true, encoding: String.Encoding.utf8)
                        
        }catch{
            
            /* error handling here */
            
        }
        
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
        
        NSPasteboard.general().clearContents()
        NSPasteboard.general().writeObjects(["//Build Time for this method is \(item.time)" as NSPasteboardWriting])
        if canAddCommentWhenClick {
        self.writeTo(filePath: item.path, comment: "\(NEW_LINE_DELIMITER) //Build Time for this method is \(item.time) ms \(NEW_LINE_DELIMITER)", lineNumber: item.location - 1)
        }
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
    
    func derivedDataDidChange() {
        projectSelection.listFolders()
    }
}

// MARK: ProjectSelectionDelegate

extension ViewController: ProjectSelectionDelegate {
    func didSelectProject(with database: XcodeDatabase) {
        processLog(with: database)
    }
}
