import Foundation
import Services

final class DatabaseConfigurationAgent: AIAgent {
    let id: String = UUID().uuidString
    let type: AIAgentType = .databaseConfiguration
    private(set) var status: AIAgentStatus = .idle
    
    @Injected(\.aiService)
    private var aiService: any AIServiceProtocol
    
    // Predefined templates for common object types
    private let objectTypeTemplates: [String: [String: Any]] = [
        "note": [
            "relations": [
                BundledRelationKey.tag.rawValue,
                BundledRelationKey.status.rawValue,
                BundledRelationKey.date.rawValue,
                BundledRelationKey.description.rawValue
            ],
            "defaultLayout": "document",
            "features": ["autoTagging", "statusTracking", "dateManagement"]
        ],
        "task": [
            "relations": [
                BundledRelationKey.status.rawValue,
                BundledRelationKey.deadline.rawValue,
                BundledRelationKey.priority.rawValue,
                BundledRelationKey.assignee.rawValue
            ],
            "defaultLayout": "kanban",
            "features": ["statusTracking", "deadlineAlerts", "priorityManagement"]
        ],
        "document": [
            "relations": [
                BundledRelationKey.tag.rawValue,
                BundledRelationKey.lastModifiedDate.rawValue,
                BundledRelationKey.author.rawValue,
                BundledRelationKey.version.rawValue
            ],
            "defaultLayout": "document",
            "features": ["versionControl", "authorTracking", "autoTagging"]
        ]
    ]
    
    func process(task: AITask) async throws -> AITaskResult {
        guard case .configureDatabase = task.type else {
            throw AISwarmError.processingFailed
        }
        
        status = .processing
        
        do {
            // Analyze content to determine object type
            let objectType = try await determineObjectType(from: task.metadata)
            
            // Get or create appropriate configuration
            let configuration = try await generateConfiguration(
                for: objectType,
                based: task.metadata
            )
            
            // Apply the configuration
            try await applyConfiguration(configuration, to: task.objectId)
            
            status = .idle
            return AITaskResult(
                taskId: task.id,
                status: .completed,
                result: configuration,
                error: nil
            )
        } catch {
            status = .error(error)
            throw error
        }
    }
    
    private func determineObjectType(from metadata: [String: Any]) async throws -> String {
        // Analyze content and metadata to determine the best object type
        // For now, defaulting to "note" if can't determine
        guard let content = metadata["content"] as? String else {
            return "note"
        }
        
        // Use AI service to analyze content and suggest type
        let prompt = """
        Analyze this content and determine if it's a:
        1. note (general content, thoughts, ideas)
        2. task (actionable items, todos)
        3. document (formal documentation, long-form content)
        Content: \(content)
        Return only the type: note, task, or document
        """
        
        if let config = aiConfigBuilder.makeOpenAIConfig() {
            let result = try await aiService.aiListSummary(
                spaceId: metadata["spaceId"] as? String ?? "",
                objectIds: [metadata["objectId"] as? String ?? ""],
                prompt: prompt,
                config: config
            )
            
            let suggestedType = result.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return objectTypeTemplates[suggestedType] != nil ? suggestedType : "note"
        }
        
        return "note"
    }
    
    private func generateConfiguration(
        for objectType: String,
        based metadata: [String: Any]
    ) async throws -> [String: Any] {
        var config = objectTypeTemplates[objectType] ?? [:]
        
        // Enhance configuration based on content analysis
        if let content = metadata["content"] as? String {
            // Use AI to suggest additional relations or features
            let suggestedEnhancements = try await suggestEnhancements(for: content)
            config.merge(suggestedEnhancements) { current, _ in current }
        }
        
        return config
    }
    
    private func suggestEnhancements(for content: String) async throws -> [String: Any] {
        guard let config = aiConfigBuilder.makeOpenAIConfig() else {
            return [:]
        }
        
        let prompt = """
        Analyze this content and suggest metadata relations that would be useful.
        Focus on practical, frequently-used relations.
        Content: \(content)
        Return a comma-separated list of relation keys.
        """
        
        let suggestions = try await aiService.aiListSummary(
            spaceId: "",
            objectIds: [],
            prompt: prompt,
            config: config
        )
        
        let relations = suggestions
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        return ["suggestedRelations": relations]
    }
    
    private func applyConfiguration(_ configuration: [String: Any], to objectId: String) async throws {
        // Here we would integrate with the object service to apply the configuration
        // This is a placeholder for the actual implementation
        status = .processing
        
        // Simulate configuration application
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        status = .idle
    }
    
    func updateMetadata(for objectId: String) async throws {
        // Implementation for metadata updates
        // This would be called periodically to keep metadata fresh
    }
}
