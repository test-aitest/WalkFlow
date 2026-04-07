import Foundation

struct ApprovalRequest: Equatable, Sendable, Codable {
    let id: String
    let description: String
    let command: String
}

enum TaskState: Equatable, Sendable {
    case idle
    case listening
    case sendingToAgent
    case awaitingApproval(ApprovalRequest)
    case listeningModification
    case executing(String)
    case taskComplete
    case error(String)
}
