//
//  AppDelegate.swift
//  BuildTimeAnalyzer
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var projectSelectionMenuItem: NSMenuItem!
    @IBOutlet weak var buildTimesMenuItem: NSMenuItem!
    @IBOutlet weak var alwaysInFrontMenuItem: NSMenuItem!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        alwaysInFrontMenuItem.state = UserSettings.windowShouldBeTopMost ? NSOnState : NSOffState
    }
    
    var viewController: ViewController? {
        return NSApplication.shared().mainWindow?.contentViewController as? ViewController
    }
    
    func configureMenuItems(showBuildTimesMenuItem: Bool) {
        projectSelectionMenuItem.isEnabled = !showBuildTimesMenuItem
        buildTimesMenuItem.isEnabled = showBuildTimesMenuItem
    }
    
    // MARK: Actions
    
    @IBAction func navigateToProjectSelection(_ sender: NSMenuItem) {
        configureMenuItems(showBuildTimesMenuItem: true)
        
        viewController?.cancelProcessing()
        viewController?.showInstructions(true)
    }
    
    @IBAction func navigateToBuildTimes(_ sender: NSMenuItem) {
        configureMenuItems(showBuildTimesMenuItem: false)
        viewController?.showInstructions(false)
    }
    
    @IBAction func visitGitHubPage(_ sender: AnyObject) {
        let path = "https://github.com/RobertGummesson/BuildTimeAnalyzer-for-Xcode"
        if let url = URL(string: path) {
            NSWorkspace.shared().open(url)
        }
    }
    
    @IBAction func toggleAlwaysInFront(_ sender: NSMenuItem) {
        let alwaysInFront = sender.state == NSOffState
        
        sender.state = alwaysInFront ? NSOnState : NSOffState
        UserSettings.windowShouldBeTopMost = alwaysInFront
        
        viewController?.makeWindowTopMost(topMost: alwaysInFront)
    }
}

