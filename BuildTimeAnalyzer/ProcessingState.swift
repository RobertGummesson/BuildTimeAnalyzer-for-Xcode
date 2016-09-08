//
//  ProcessingState.swift
//  BuildTimeAnalyzer
//

enum ProcessingState {
    case processing
    case waiting(shouldIndicate: Bool)
    case completed(didSucceed: Bool, stateName: String)

    static let cancelledString       = "Cancelled"
    static let completedString       = "Completed"
    static let failedString          = "No valid logs found"
    static let processingString      = "Processing log..."
    static let waitingForBuildString = "Waiting..."
    static let buildString           = "Building..."
}

extension ProcessingState : Equatable {}

func ==(lhs: ProcessingState, rhs: ProcessingState) -> Bool {
    switch (lhs, rhs) {
    case (let .waiting(shouldIndicate1), let .waiting(shouldIndicate2)):
        return shouldIndicate1 == shouldIndicate2
        
    case (let .completed(didSucceed1, _), let .completed(didSucceed2, _)):
        return didSucceed1 == didSucceed2
        
    case (.processing, .processing):
        return true
        
    default:
        return false
    }
}
