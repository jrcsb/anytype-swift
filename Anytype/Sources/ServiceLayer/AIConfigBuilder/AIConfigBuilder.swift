import Foundation
import Services

protocol AIConfigBuilderProtocol {
    func makeOpenAIConfig() -> AIProviderConfig?
    func makeLocalConfig() -> AIProviderConfig?
    var preferredProvider: AIProvider { get }
}

final class AIConfigBuilder: AIConfigBuilderProtocol {
    @Injected(\.ollamaConfigBuilder)
    private var ollamaConfig: any OllamaConfigBuilderProtocol
    
    @Injected(\.localModelManager)
    private var modelManager: any LocalModelManagerProtocol
    
    // UserDefaults key for storing preferred provider
    private let preferredProviderKey = "PreferredAIProvider"
    
    private var endpoint: String? {
        Bundle.main.object(forInfoDictionaryKey: "AIEndpoint") as? String
    }
    
    private var model: String? {
        Bundle.main.object(forInfoDictionaryKey: "AIModel") as? String
    }
    
    private var token: String? {
        Bundle.main.object(forInfoDictionaryKey: "OpenAIToken") as? String
    }
    
    var preferredProvider: AIProvider {
        get {
            let storedValue = UserDefaults.standard.integer(forKey: preferredProviderKey)
            return AIProvider(rawValue: storedValue) ?? .ollama
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredProviderKey)
        }
    }
    
    func makeOpenAIConfig() -> AIProviderConfig? {
        guard let endpoint, endpoint.isNotEmpty,
              let model, model.isNotEmpty,
              let token, token.isNotEmpty else {
            return nil
        }
        
        var config = AIProviderConfig()
        config.provider = .openai
        config.endpoint = endpoint
        config.model = model
        config.token = token
        config.temperature = 0.2
        
        return config
    }
    
    func makeLocalConfig() -> AIProviderConfig? {
        return ollamaConfig.makeOllamaConfig(model: ollamaConfig.defaultModel)
    }
    
    // Get the best available configuration
    func getBestConfig(for taskType: AITaskType) async -> AIProviderConfig? {
        switch preferredProvider {
        case .ollama:
            // Try local first, fallback to OpenAI
            if let localConfig = makeLocalConfig(),
               let status = try? await modelManager.getModelStatus(localConfig.model),
               status == .ready {
                return localConfig
            }
            return makeOpenAIConfig()
            
        case .openai:
            // Try OpenAI first, fallback to local
            if let openAIConfig = makeOpenAIConfig() {
                return openAIConfig
            }
            return makeLocalConfig()
            
        default:
            // For any other provider, default to local
            return makeLocalConfig()
        }
    }
}
