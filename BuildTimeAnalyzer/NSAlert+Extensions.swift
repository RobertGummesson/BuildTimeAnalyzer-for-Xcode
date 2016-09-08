//
//  NSAlert+Extensions.swift
//  BuildTimeAnalyzer
//

import Cocoa

extension NSAlert {
    static func show(withMessage message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
