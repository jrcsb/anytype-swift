import Foundation
import Services

protocol AIAgentSwarmProtocol {
    func registerAgent(_ agent: AIAgent)
    func processTask(_ task: AITask) async throws -> AITaskResult
    func getAvailableAgents() -> [AIAgent]
    func configureSwarm(config: AIProviderConfig)
    func autoConfigureObject(_ objectId: String, content: String, spaceId: String) async throws
}

final class AIAgentSwarm: AIAgentSwarmProtocol {
    private var agents: [String: AIAgent] = [:]
    private var config: AIProviderConfig?
    private let queueManager = AITaskQueueManager()
    
    @Injected(\.aiService)
    private var aiService: any AIServiceProtocol
    
    init() {}
    
    func getQueueStatus() async -> AIQueueStatus {
        await queueManager.getQueueStatus()
    }
    
    func registerAgent(_ agent: AIAgent) {
        agents[agent.id] = agent
    }
    
    func processTask(_ task: AITask) async throws -> AITaskResult {
        // Find appropriate agent based on task type
        guard let agent = findBestAgent(for: task.type) else {
            throw AISwarmError.noSuitableAgent
        }
        
        // Enqueue task for processing
        return try await queueManager.enqueueTask(task)
    }
    
    func cancelAllTasks() async {
        await queueManager.cancelAllTasks()
    }
    
    func getAvailableAgents() -> [AIAgent] {
        Array(agents.values)
    }
    
    func configureSwarm(config: AIProviderConfig) {
        self.config = config
    }
    
    private func findBestAgent(for taskType: AITaskType) -> AIAgent? {
        // Simple matching for now - can be enhanced with more sophisticated selection
        return agents.values.first { agent in
            switch (agent.type, taskType) {
            case (.metadataEnricher, .enrichMetadata),
                 (.dataAugmenter, .augmentContent),
                 (.configurationManager, .configureSettings),
                 (.contentAnalyzer, .analyzeContent),
                 (.databaseConfiguration, .configureDatabase):
                return agent.status == .idle
            default:
                return false
            }
        }
    }
}

    // Auto-configuration of objects with AI assistance
    func autoConfigureObject(_ objectId: String, content: String, spaceId: String) async throws {
        // First, configure the database and metadata structure
        let dbTask = AITask(
            id: UUID().uuidString,
            type: .configureDatabase,
            objectId: objectId,
            config: config ?? AIProviderConfig(),
            metadata: [
                "objectId": objectId,
                "content": content,
                "spaceId": spaceId
            ]
        )
        
        // Process database configuration with high priority
        let dbResult = try await processTask(dbTask)
        guard dbResult.status == .completed else {
            throw AISwarmError.processingFailed
        }
        
        // Then enrich metadata based on the configuration
        let metadataTask = AITask(
            id: UUID().uuidString,
            type: .enrichMetadata,
            objectId: objectId,
            config: config ?? AIProviderConfig(),
            metadata: dbResult.result
        )
        
        let _ = try await processTask(metadataTask)
        
        // Finally, optimize any settings
        let settingsTask = AITask(
            id: UUID().uuidString,
            type: .configureSettings,
            objectId: objectId,
            config: config ?? AIProviderConfig(),
            metadata: dbResult.result
        )
        
        let _ = try await processTask(settingsTask)
    }
}

enum AISwarmError: Error {
    case noSuitableAgent
    case configurationMissing
    case processingFailed
}
