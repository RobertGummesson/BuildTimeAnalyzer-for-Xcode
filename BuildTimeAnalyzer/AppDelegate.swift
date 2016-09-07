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
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // MARK: Actions
    
    @IBAction func navigateToProjectSelection(_ sender: NSMenuItem) {
        sender.isEnabled = false
        buildTimesMenuItem.isEnabled = true
        
        guard let viewController = viewController else { return }
    
        viewController.cancelProcessing()
        viewController.showInstructions(true)
    }
    
    @IBAction func navigateToBuildTimes(_ sender: NSMenuItem) {
        sender.isEnabled = false
        projectSelectionMenuItem.isEnabled = true
        
        viewController?.showInstructions(false)
    }
}

