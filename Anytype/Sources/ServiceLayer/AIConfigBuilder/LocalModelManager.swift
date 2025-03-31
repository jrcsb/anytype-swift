import Foundation
import Services

enum LocalModelStatus {
    case notDownloaded
    case downloading(progress: Double)
    case ready
    case error(String)
}

enum LocalModelError: Error {
    case downloadFailed(String)
    case modelNotFound
    case insufficientResources(required: (ram: Int, disk: Int))
}

protocol LocalModelManagerProtocol {
    func downloadModel(_ model: String) async throws
    func getModelStatus(_ model: String) async -> LocalModelStatus
    func checkSystemRequirements(for model: String) async throws
    func getAllModelStatuses() async -> [String: LocalModelStatus]
}

final class LocalModelManager: LocalModelManagerProtocol {
    @Injected(\.ollamaConfigBuilder)
    private var configBuilder: OllamaConfigBuilderProtocol
    
    private var modelStatuses: [String: LocalModelStatus] = [:]
    
    func downloadModel(_ model: String) async throws {
        // Check system requirements first
        try await checkSystemRequirements(for: model)
        
        // Update status to downloading
        modelStatuses[model] = .downloading(progress: 0.0)
        
        do {
            // Execute Ollama pull command
            try await executeOllamaPull(model)
            modelStatuses[model] = .ready
        } catch {
            modelStatuses[model] = .error(error.localizedDescription)
            throw LocalModelError.downloadFailed(error.localizedDescription)
        }
    }
    
    func getModelStatus(_ model: String) async -> LocalModelStatus {
        if let status = modelStatuses[model] {
            return status
        }
        
        // Check if model exists locally
        do {
            let exists = try await checkModelExists(model)
            let status: LocalModelStatus = exists ? .ready : .notDownloaded
            modelStatuses[model] = status
            return status
        } catch {
            return .error("Failed to check model status")
        }
    }
    
    func checkSystemRequirements(for model: String) async throws {
        guard let requirements = configBuilder.getModelRequirements(for: model) else {
            throw LocalModelError.modelNotFound
        }
        
        let availableResources = try await getAvailableResources()
        
        if availableResources.ram < requirements.ram || availableResources.disk < requirements.disk {
            throw LocalModelError.insufficientResources(required: requirements)
        }
    }
    
    func getAllModelStatuses() async -> [String: LocalModelStatus] {
        var statuses: [String: LocalModelStatus] = [:]
        
        do {
            let models = try await configBuilder.getAvailableModels()
            for model in models {
                statuses[model] = await getModelStatus(model)
            }
        } catch {
            // If we can't get models list, return existing statuses
            return modelStatuses
        }
        
        return statuses
    }
    
    // MARK: - Private Methods
    
    private func executeOllamaPull(_ model: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        process.arguments = ["pull", model]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw LocalModelError.downloadFailed("Model download failed with status \(process.terminationStatus)")
        }
    }
    
    private func checkModelExists(_ model: String) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        process.arguments = ["list"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.contains(model)
    }
    
    private func getAvailableResources() async throws -> (ram: Int, disk: Int) {
        // Get available RAM
        let host = UnsafeMutablePointer<host_basic_info>.allocate(capacity: 1)
        var size = mach_msg_type_number_t(MemoryLayout<host_basic_info>.size / MemoryLayout<integer_t>.size)
        let kerr = host_info(mach_host_self(), HOST_BASIC_INFO, host.withMemoryRebound(to: integer_t.self, capacity: 1) { $0 }, &size)
        let ramGB = (kerr == KERN_SUCCESS) ? Int(host.pointee.max_mem) / 1024 / 1024 / 1024 : 0
        host.deallocate()
        
        // Get available disk space
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        guard let resources = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let diskSpace = resources.volumeAvailableCapacity else {
            throw LocalModelError.downloadFailed("Could not determine available disk space")
        }
        let diskGB = diskSpace / 1024 / 1024 / 1024
        
        return (ram: ramGB, disk: Int(diskGB))
    }
}
