//
//  NSAlert+Extensions.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 08/09/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
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
