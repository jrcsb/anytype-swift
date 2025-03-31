import Foundation
import Services

protocol OllamaConfigBuilderProtocol {
    func makeOllamaConfig(model: String) -> AIProviderConfig
    func getAvailableModels() async throws -> [String]
    func getModelRequirements(for model: String) -> (ram: Int, disk: Int)?
    func getModelDescription(for model: String) -> String?
    func recommendModel(for taskType: AITaskType) -> String
    var defaultModel: String { get }
}

final class OllamaConfigBuilder: OllamaConfigBuilderProtocol {
    // Default local endpoint for Ollama
    private let defaultEndpoint = "http://localhost:11434"
    
    // Default model to use
    let defaultModel = "llama2"
    
    // Supported models for different tasks
    private let supportedModels = [
        "llama2": "General purpose model, good balance of performance and quality",
        "codellama": "Specialized for code understanding and generation",
        "mistral": "Strong reasoning and analysis capabilities",
        "phi": "Efficient for smaller tasks",
        "neural-chat": "Optimized for conversation and analysis",
        "orca-mini": "Light and fast for basic tasks"
    ]
    
    func makeOllamaConfig(model: String = "llama2") -> AIProviderConfig {
        var config = AIProviderConfig()
        config.provider = .ollama
        config.endpoint = defaultEndpoint
        config.model = model
        config.temperature = 0.7 // Slightly more creative than OpenAI default
        
        return config
    }
    
    func getAvailableModels() async throws -> [String] {
        // In a real implementation, this would query the Ollama API
        // For now, returning supported models
        return Array(supportedModels.keys)
    }
    
    // Helper method to get model description
    func getModelDescription(for model: String) -> String? {
        return supportedModels[model]
    }
    
    // Get recommended model for specific task type
    func recommendModel(for taskType: AITaskType) -> String {
        switch taskType {
        case .configureDatabase:
            return "codellama" // Better for structured data
        case .enrichMetadata:
            return "mistral" // Good at analysis and categorization
        case .configureSettings:
            return "neural-chat" // Better for understanding user preferences
        case .analyzeContent:
            return "llama2" // Good general-purpose model
        case .augmentContent:
            return "phi" // Efficient for smaller augmentation tasks
        }
    }
    
    // Get system requirements for model
    func getModelRequirements(for model: String) -> (ram: Int, disk: Int)? {
        // Approximate requirements in GB
        switch model {
        case "llama2":
            return (ram: 16, disk: 4)
        case "codellama":
            return (ram: 16, disk: 4)
        case "mistral":
            return (ram: 8, disk: 2)
        case "phi":
            return (ram: 4, disk: 1)
        case "neural-chat":
            return (ram: 8, disk: 2)
        case "orca-mini":
            return (ram: 4, disk: 1)
        default:
            return nil
        }
    }
}
