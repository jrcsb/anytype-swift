import Foundation
import SwiftUI
import Services

@MainActor
final class LocalModelSettingsViewModel: ObservableObject {
    @Injected(\.localModelManager)
    private var modelManager: any LocalModelManagerProtocol
    
    @Injected(\.ollamaConfigBuilder)
    private var configBuilder: any OllamaConfigBuilderProtocol
    
    @Published private(set) var modelStatuses: [String: LocalModelStatus] = [:]
    @Published private(set) var selectedModel: String
    @Published var error: Error?
    @Published private(set) var isLoading = false
    
    init() {
        self.selectedModel = configBuilder.defaultModel
        Task {
            await refreshModelStatuses()
        }
    }
    
    func refreshModelStatuses() async {
        isLoading = true
        modelStatuses = await modelManager.getAllModelStatuses()
        isLoading = false
    }
    
    func downloadModel(_ model: String) async {
        do {
            try await modelManager.downloadModel(model)
            await refreshModelStatuses()
        } catch {
            self.error = error
        }
    }
    
    func selectModel(_ model: String) async {
        do {
            let status = await modelManager.getModelStatus(model)
            guard status == .ready else {
                try await downloadModel(model)
                return
            }
            selectedModel = model
        } catch {
            self.error = error
        }
    }
    
    func getModelDescription(_ model: String) -> String {
        configBuilder.getModelDescription(for: model) ?? "No description available"
    }
    
    func getRequirements(for model: String) -> String {
        guard let req = configBuilder.getModelRequirements(for: model) else {
            return "Requirements unknown"
        }
        return "RAM: \(req.ram)GB, Disk: \(req.disk)GB"
    }
    
    func getStatusDescription(for model: String) -> String {
        guard let status = modelStatuses[model] else {
            return "Unknown"
        }
        
        switch status {
        case .notDownloaded:
            return "Not Downloaded"
        case .downloading(let progress):
            return "Downloading (\(Int(progress * 100))%)"
        case .ready:
            return "Ready"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    func getStatusColor(for model: String) -> Color {
        guard let status = modelStatuses[model] else {
            return .gray
        }
        
        switch status {
        case .notDownloaded:
            return .gray
        case .downloading:
            return .blue
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    func isModelAvailable(_ model: String) -> Bool {
        guard let status = modelStatuses[model] else {
            return false
        }
        return status == .ready
    }
}
