//
//  CMProcessingState.swift
//  BuildTimeAnalyzer
//
//  Created by Robert Gummesson on 01/05/2016.
//  Copyright © 2016 Robert Gummesson. All rights reserved.
//

enum CMProcessingState {
    case processing
    case waiting(shouldIndicate: Bool)
    case completed(stateName: String)

    static let cancelledString       = "Cancelled"
    static let completedString       = "Completed"
    static let failedString          = "No valid logs found"
    static let processingString      = "Processing log..."
    static let waitingForBuildString = "Waiting..."
    static let buildString           = "Building..."
}

extension CMProcessingState : Equatable {}

func ==(lhs: CMProcessingState, rhs: CMProcessingState) -> Bool {
    switch (lhs, rhs) {
    case (let .waiting(shouldIndicate1), let .waiting(shouldIndicate2)):
        return shouldIndicate1 == shouldIndicate2
        
    case (let .completed(stateName1), let .completed(stateName2)):
        return stateName1 == stateName2
        
    case (.processing, .processing):
        return true
        
    default:
        return false
    }
}