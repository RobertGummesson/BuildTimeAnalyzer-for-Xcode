//
//  NSAlert+Extensions.swift
//  BuildTimeAnalyzer
//

import Cocoa

extension NSAlert {
    static func show(withMessage message: String, andInformativeText informativeText: String = "") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
