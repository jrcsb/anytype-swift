protocol AIAgent {
    var id: String { get }
    var type: AIAgentType { get }
    var status: AIAgentStatus { get }
    
    func process(task: AITask) async throws -> AITaskResult
    func updateMetadata(for objectId: String) async throws
}

enum AIAgentType {
    case metadataEnricher
    case dataAugmenter
    case configurationManager
    case contentAnalyzer
    case databaseConfiguration
}

enum AIAgentStatus {
    case idle
    case processing
    case error(Error)
}

struct AITask {
    let id: String
    let type: AITaskType
    let objectId: String
    let config: AIProviderConfig
    var metadata: [String: Any]
}

enum AITaskType {
    case enrichMetadata
    case augmentContent
    case configureSettings
    case analyzeContent
    case configureDatabase
    
    var defaultPriority: TaskPriority {
        switch self {
        case .configureDatabase:
            return .critical // Database configuration should happen first
        case .configureSettings:
            return .high
        case .enrichMetadata:
            return .medium
        case .analyzeContent:
            return .medium
        case .augmentContent:
            return .low
        }
    }
}

struct AITaskResult {
    let taskId: String
    let status: AITaskStatus
    let result: [String: Any]
    let error: Error?
}

enum AITaskStatus {
    case completed
    case failed
    case partial
}
