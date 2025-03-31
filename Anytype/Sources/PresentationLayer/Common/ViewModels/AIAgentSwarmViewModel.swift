import Foundation
import Factory
import SwiftUI

@MainActor
final class AIAgentSwarmViewModel: ObservableObject {
    @Injected(\.aiAgentSwarmService)
    private var swarmService: any AIAgentSwarmServiceProtocol
    
    @Injected(\.aiConfigBuilder)
    private var configBuilder: any AIConfigBuilderProtocol
    
    @Published private(set) var isProcessing = false
    @Published private(set) var agentStatuses: [String: AIAgentStatus] = [:]
    @Published private(set) var queueStatus: AIQueueStatus?
    @Published private(set) var autoConfigurationComplete = false
    @Published var error: Error?
    
    func autoConfigureObject(objectId: String, content: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        error = nil
        autoConfigurationComplete = false
        
        // Start periodic queue status updates
        startQueueStatusUpdates()
        
        do {
            try await swarmService.autoConfigureObject(objectId: objectId, content: content)
            autoConfigurationComplete = true
        } catch {
            self.error = error
        }
        
        isProcessing = false
        stopQueueStatusUpdates()
    }
    
    func enrichObjectMetadata(objectId: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        error = nil
        
        // Start periodic queue status updates
        startQueueStatusUpdates()
        
        do {
            // Configure swarm if needed
            if let config = configBuilder.makeOpenAIConfig() {
                swarmService.setupSwarm(with: config)
            }
            
            // Process metadata enrichment
            try await swarmService.enrichMetadata(for: objectId)
            
            // Update agent statuses
            agentStatuses = swarmService.getAgentStatus()
        } catch {
            self.error = error
        }
        
        isProcessing = false
        stopQueueStatusUpdates()
    }
    
    func optimizeObjectConfiguration(objectId: String) async {
        guard !isProcessing else { return }
        isProcessing = true
        error = nil
        
        do {
            // Configure swarm if needed
            if let config = configBuilder.makeOpenAIConfig() {
                swarmService.setupSwarm(with: config)
            }
            
            // Process configuration optimization
            try await swarmService.optimizeConfiguration(for: objectId)
            
            // Update agent statuses
            agentStatuses = swarmService.getAgentStatus()
        } catch {
            self.error = error
        }
        
        isProcessing = false
        stopQueueStatusUpdates()
    }
    
    func cancelAllTasks() async {
        await swarmService.cancelAllTasks()
        stopQueueStatusUpdates()
    }
    
    private var statusUpdateTimer: Timer?
    
    private func startQueueStatusUpdates() {
        // Update immediately
        Task {
            queueStatus = await swarmService.getQueueStatus()
        }
        
        // Setup periodic updates
        statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                self?.queueStatus = await self?.swarmService.getQueueStatus()
            }
        }
    }
    
    private func stopQueueStatusUpdates() {
        statusUpdateTimer?.invalidate()
        statusUpdateTimer = nil
    }
    
    func getQueueStatusDescription() -> String {
        guard let status = queueStatus else { return "Queue status unknown" }
        return """
        Active tasks: \(status.activeTasks)
        Pending tasks: \(status.pendingTasks)
        Cached results: \(status.cachedResults)
        """
    }
    
    func getAgentStatusDescription(for agentId: String) -> String {
        guard let status = agentStatuses[agentId] else {
            return "Unknown"
        }
        
        switch status {
        case .idle:
            return "Ready"
        case .processing:
            return "Processing"
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }
}
