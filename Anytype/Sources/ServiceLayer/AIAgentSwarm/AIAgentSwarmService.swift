import Foundation
import Services

protocol AIAgentSwarmServiceProtocol {
    func setupSwarm(with config: AIProviderConfig)
    func enrichMetadata(for objectId: String) async throws
    func optimizeConfiguration(for objectId: String) async throws
    func getAgentStatus() -> [String: AIAgentStatus]
    func getQueueStatus() async -> AIQueueStatus
    func cancelAllTasks() async
    func autoConfigureObject(objectId: String, content: String) async throws
}

final class AIAgentSwarmService: AIAgentSwarmServiceProtocol {
    private let swarm: AIAgentSwarmProtocol
    
    @Injected(\.aiService)
    private var aiService: any AIServiceProtocol
    
    @Injected(\.aiConfigBuilder)
    private var aiConfigBuilder: any AIConfigBuilderProtocol
    
    init() {
        self.swarm = AIAgentSwarm()
        setupDefaultAgents()
    }
    
    func setupSwarm(with config: AIProviderConfig) {
        swarm.configureSwarm(config: config)
    }
    
    func enrichMetadata(for objectId: String) async throws {
        guard let config = await aiConfigBuilder.getBestConfig(for: .enrichMetadata) else {
            throw AISwarmError.configurationMissing
        }
        
        let task = AITask(
            id: UUID().uuidString,
            type: .enrichMetadata,
            objectId: objectId,
            config: config,
            metadata: [:]
        )
        
        let result = try await swarm.processTask(task)
        
        guard result.status == .completed else {
            throw result.error ?? AISwarmError.processingFailed
        }
    }
    
    func optimizeConfiguration(for objectId: String) async throws {
        guard let config = await aiConfigBuilder.getBestConfig(for: .configureSettings) else {
            throw AISwarmError.configurationMissing
        }
        
        let task = AITask(
            id: UUID().uuidString,
            type: .configureSettings,
            objectId: objectId,
            config: config,
            metadata: [:]
        )
        
        let result = try await swarm.processTask(task)
        
        guard result.status == .completed else {
            throw result.error ?? AISwarmError.processingFailed
        }
    }
    
    func getAgentStatus() -> [String: AIAgentStatus] {
        let agents = swarm.getAvailableAgents()
        return Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0.status) })
    }
    
    func getQueueStatus() async -> AIQueueStatus {
        await swarm.getQueueStatus()
    }
    
    func cancelAllTasks() async {
        await swarm.cancelAllTasks()
    }
    
    func autoConfigureObject(objectId: String, content: String) async throws {
        guard let config = await aiConfigBuilder.getBestConfig(for: .configureDatabase) else {
            throw AISwarmError.configurationMissing
        }
        
        // Get space ID from the object (you might need to implement this)
        let spaceId = try await getSpaceId(for: objectId)
        
        // Use the swarm to handle auto-configuration
        try await swarm.autoConfigureObject(objectId, content: content, spaceId: spaceId)
    }
    
    private func getSpaceId(for objectId: String) async throws -> String {
        // TODO: Implement actual space ID retrieval
        // For now returning a placeholder
        return "default-space"
    }
    
    private func setupDefaultAgents() {
        // Initialize and register default agents
        let metadataAgent = MetadataEnricherAgent()
        let configManager = ConfigurationManagerAgent()
        let dbConfigAgent = DatabaseConfigurationAgent()
        
        swarm.registerAgent(metadataAgent)
        swarm.registerAgent(configManager)
        swarm.registerAgent(dbConfigAgent)
    }
}
