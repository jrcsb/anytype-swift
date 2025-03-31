import Foundation
import Services

/// Triggers automatic configuration when objects are created or significantly modified
final class AIAutoConfigurationTrigger {
    @Injected(\.aiAgentSwarmService)
    private var swarmService: any AIAgentSwarmServiceProtocol
    
    private var configurationThresholds: [String: TimeInterval] = [:]
    private let minTimeBetweenConfigurations: TimeInterval = 300 // 5 minutes
    
    // Content change threshold that triggers reconfiguration
    private let contentChangeThreshold = 0.3 // 30% change
    
    func handleObjectCreated(_ objectId: String, content: String) async {
        // New objects should always be configured
        try? await swarmService.autoConfigureObject(objectId: objectId, content: content)
    }
    
    func handleObjectModified(_ objectId: String, content: String, previousContent: String?) async {
        guard shouldReconfigure(objectId: objectId, newContent: content, previousContent: previousContent) else {
            return
        }
        
        try? await swarmService.autoConfigureObject(objectId: objectId, content: content)
        updateConfigurationTimestamp(for: objectId)
    }
    
    private func shouldReconfigure(objectId: String, newContent: String, previousContent: String?) -> Bool {
        // Check if enough time has passed since last configuration
        if let lastConfiguration = configurationThresholds[objectId] {
            let timeSinceLastConfig = Date().timeIntervalSince1970 - lastConfiguration
            guard timeSinceLastConfig >= minTimeBetweenConfigurations else {
                return false
            }
        }
        
        // For new content, always configure
        guard let previousContent = previousContent else {
            return true
        }
        
        // Check if content has changed significantly
        let changeRatio = calculateContentChangeRatio(new: newContent, old: previousContent)
        return changeRatio >= contentChangeThreshold
    }
    
    private func calculateContentChangeRatio(new: String, old: String) -> Double {
        let oldWords = Set(old.split(separator: " ").map(String.init))
        let newWords = Set(new.split(separator: " ").map(String.init))
        
        let addedWords = newWords.subtracting(oldWords)
        let removedWords = oldWords.subtracting(newWords)
        
        let totalChanges = Double(addedWords.count + removedWords.count)
        let totalWords = Double(max(oldWords.count, newWords.count))
        
        guard totalWords > 0 else { return 0 }
        return totalChanges / totalWords
    }
    
    private func updateConfigurationTimestamp(for objectId: String) {
        configurationThresholds[objectId] = Date().timeIntervalSince1970
    }
    
    func clearConfigurationHistory(for objectId: String) {
        configurationThresholds.removeValue(forKey: objectId)
    }
}
