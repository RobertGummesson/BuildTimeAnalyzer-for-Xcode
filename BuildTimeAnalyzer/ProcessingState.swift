//
//  ProcessingState.swift
//  BuildTimeAnalyzer
//

enum ProcessingState {
    case processing
    case waiting
    case completed(didSucceed: Bool, stateName: String)

    static let cancelledString       = "Cancelled"
    static let completedString       = "Completed"
    static let failedString          = "No valid logs found"
    static let processingString      = "Processing log..."
    static let waitingForBuildString = "Waiting..."
}

extension ProcessingState : Equatable {
    static func ==(lhs: ProcessingState, rhs: ProcessingState) -> Bool {
        switch (lhs, rhs) {
        case let (.completed(didSucceed1, _), .completed(didSucceed2, _)):
            return didSucceed1 == didSucceed2
        case (.processing, .processing), (.waiting, .waiting):
            return true
        default:
            return false
        }
    }
}


