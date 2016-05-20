//
//  CMPlugin.swift
//  CMPlugin
//
//  Created by Robert Gummesson on 29/04/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import AppKit

class CMPlugin: NSObject {
    
    static var sharedPlugin: CMPlugin?
    var windowController: CMResultWindowController?
    
    var applicationDidFinishLaunchingObserver: AnyObject?
    var startStateDescription = ""
    
    class func pluginDidLoad(bundle: NSBundle) {
        let appName = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String
        if appName == "Xcode" && sharedPlugin == nil {
            sharedPlugin = CMPlugin()
        }
    }
    
    override init() {
        super.init()
        
        applicationDidFinishLaunchingObserver = NSNotificationCenter.addObserverForName(NSApplicationDidFinishLaunchingNotification, usingBlock: { [unowned self] _ in
            self.createMenuItem()
        })
    }
    
    deinit {
        NSNotificationCenter.removeObserver(applicationDidFinishLaunchingObserver, name: NSApplicationDidFinishLaunchingNotification)
    }
    
    func createMenuItem() {
        guard let submenu = NSApp.mainMenu?.itemWithTitle("View")?.submenu else { return }
        
        let title = NSLocalizedString("Build Time Analyzer", comment: "")
        let menuItem = NSMenuItem(title: title, action: "showWindow", keyEquivalent: "")
        menuItem.target = self
        menuItem.keyEquivalent = "b"
        menuItem.keyEquivalentModifierMask = Int(NSEventModifierFlags.ShiftKeyMask.rawValue | NSEventModifierFlags.ControlKeyMask.rawValue)
        submenu.addItem(menuItem)
    }
    
    func showWindow() {
        guard windowController == nil else {
            windowController?.resultWindow.close()
            return
        }
        
        windowController = CMResultWindowController(windowNibName: "CMResultWindow")
        windowController?.show()
        
        if let window = self.windowController?.resultWindow {
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "windowWillClose:", name: NSWindowWillCloseNotification, object: window)
        }
    }
    
    func windowWillClose(notification: NSNotification) {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSWindowWillCloseNotification, object: notification.object as? NSWindow)
        self.windowController = nil
    }
}