//
//  AppDelegate.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 27/06/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var projectSelectionMenuItem: NSMenuItem!
    @IBOutlet weak var buildTimesMenuItem: NSMenuItem!
    
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
        
        guard let viewController = viewController else { return }
    
        viewController.cancelProcessing()
        viewController.showInstructions(true)
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
}

