//
//  CMSourceEditorNavigator.swift
//  BuildTimeAnalyzer
//
//  Created by Dat Nguyen on 5/7/16.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

import AppKit

class CMXcodeNavigator {
    static func openFile(atPath path: String, andLineNumber lineNumber: Int, onCompleted: () -> Void) {
        // TODO: Work out how to jump to the line number.
        // Need to be notified when it has opened
        NSApp.delegate?.application?(NSApp, openFile: path)
        
        // Need to wait 200ms to make sure open file completed, then scroll to line number.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * Int64(NSEC_PER_MSEC)), dispatch_get_main_queue()) {
            if let activeEditorView = DVTSourceTextView.activeEditorView,
                selectedRange = (activeEditorView.sourceCode as NSString?)?.getRangeOfLine(lineNumber)
            {
                activeEditorView.scrollRangeToVisible(selectedRange)
                activeEditorView.setSelectedRange(selectedRange)
                onCompleted()
            }
        }
    }
}


extension DVTSourceTextView {
    static var activeEditorView: DVTSourceTextView? {
        let windowController = NSApplication.sharedApplication().keyWindow?.windowController as? IDEWorkspaceWindowController
        let editor = windowController?.editorArea?.lastActiveEditorContext?.editor
        return editor?.mainScrollView?.contentView.documentView as? DVTSourceTextView
    }
    
    var sourceCode: String {
        return (textStorage() as! NSTextStorage).string
    }
}

extension NSString {
    private func getRangeOfLine(line: Int) -> NSRange? {
        var currentLine = 1
        var index = 0
        
        while (index < self.length) {
            let lineRange = self.lineRangeForRange(NSMakeRange(index, 0))
            index = NSMaxRange(lineRange)
            
            if currentLine == line {
                return lineRange
            }
            currentLine += 1
        }
        
        return nil
    }
}