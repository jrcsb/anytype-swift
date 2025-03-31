import Foundation
import Services

protocol AIAutomationServiceProtocol {
    func startAutomation()
    func stopAutomation()
    func clearCache(for objectId: String)
}

final class AIAutomationService: AIAutomationServiceProtocol {
    @Injected(\.aiAutoConfigTrigger)
    private var configTrigger: AIAutoConfigurationTrigger
    
    private var observer: AIObjectChangeObserver?
    
    func startAutomation() {
        // Initialize and start the observer if not already running
        if observer == nil {
            observer = AIObjectChangeObserver()
        }
    }
    
    func stopAutomation() {
        // Clean up observer
        observer = nil
    }
    
    func clearCache(for objectId: String) {
        observer?.clearCache(for: objectId)
    }
}

// Extension to help with memory management
extension AIAutomationService {
    // Call this method when app goes to background
    func handleAppBackground() {
        // Keep the service running but clear any temporary caches
        observer = nil
        observer = AIObjectChangeObserver()
    }
    
    // Call this method when memory warning is received
    func handleMemoryWarning() {
        // Clear all caches but keep the service running
        observer = nil
        observer = AIObjectChangeObserver()
    }
}
