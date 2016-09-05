//
//  DirectoryMonitor.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 04/09/2016.
//  Copyright © 2016 Cane Media Ltd. All rights reserved.
//

import Foundation

protocol DirectoryMonitorDelegate: class {
    func directoryMonitorDidObserveChange(_ directoryMonitor: DirectoryMonitor)
}

class DirectoryMonitor {
    let dispatchQueue = DispatchQueue(label: "uk.co.canemedia.directorymonitor", attributes: .concurrent)
    
    weak var delegate: DirectoryMonitorDelegate?
    
    var fileDescriptor: Int32 = -1
    var dispatchSource: DispatchSourceFileSystemObject?
    var path: String
    
    init(path: String) {
        self.path = path
    }
    
    func startMonitoring() {
        guard dispatchSource == nil && fileDescriptor == -1 else { return }
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: dispatchQueue)
        dispatchSource?.setEventHandler {
            DispatchQueue.main.async {
                self.delegate?.directoryMonitorDidObserveChange(self)
            }
        }
        dispatchSource?.setCancelHandler {
            close(self.fileDescriptor)
            
            self.fileDescriptor = -1
            self.dispatchSource = nil
        }
        dispatchSource?.resume()
    }
    
    func stopMonitoring() {
        dispatchSource?.cancel()
    }
}
