import Foundation
import Services
import Darwin

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
    func cleanupUnusedModels() async throws
    func getLastUsedDate(for model: String) async -> Date?
    func recordModelUse(model: String)
}

final class LocalModelManager: LocalModelManagerProtocol {
    private let modelUsageKey = "ModelLastUsedDates"
    private let defaultModelRetentionDays = 30
    @Injected(\.ollamaConfigBuilder)
    private var configBuilder: OllamaConfigBuilderProtocol
    
    private var modelStatuses: [String: LocalModelStatus] = [:]
    private let userDefaults = UserDefaults.standard
    let modelCache: ModelDiskCache // Changed to internal access for testing
    
    init() throws {
        self.modelCache = try ModelDiskCache()
    }
    
    func getLastUsedDate(for model: String) async -> Date? {
        guard let usageDates = userDefaults.dictionary(forKey: modelUsageKey) as? [String: TimeInterval] else {
            return nil
        }
        guard let lastUsed = usageDates[model] else {
            return nil
        }
        return Date(timeIntervalSince1970: lastUsed)
    }
    
    func recordModelUse(model: String) {
        var usageDates = userDefaults.dictionary(forKey: modelUsageKey) as? [String: TimeInterval] ?? [:]
        usageDates[model] = Date().timeIntervalSince1970
        userDefaults.set(usageDates, forKey: modelUsageKey)
    }
    
    func cleanupUnusedModels() async throws {
        let models = try await configBuilder.getAvailableModels()
        let now = Date()
        
        for model in models {
            if let lastUsed = await getLastUsedDate(for: model) {
                let daysSinceLastUse = Calendar.current.dateComponents([.day], from: lastUsed, to: now).day ?? 0
                if daysSinceLastUse > defaultModelRetentionDays {
                    try await removeModel(model)
                }
            }
        }
    }
    
    private func removeModel(_ model: String) async throws {
        do {
            // Remove from Ollama
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
            process.arguments = ["rm", model]
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus != 0 {
                throw LocalModelError.downloadFailed("Failed to remove model \(model)")
            }
            
            // Remove from disk cache
            try modelCache.removeCachedModel(model)
            
            // Clean up usage data
            var usageDates = userDefaults.dictionary(forKey: modelUsageKey) as? [String: TimeInterval] ?? [:]
            usageDates.removeValue(forKey: model)
            userDefaults.set(usageDates, forKey: modelUsageKey)
            modelStatuses.removeValue(forKey: model)
            
        } catch {
            // If any step fails, ensure we clean up everything
            try? modelCache.removeCachedModel(model)
            modelStatuses.removeValue(forKey: model)
            throw error
        }
    }
    
    func downloadModel(_ model: String) async throws {
        // Check system requirements first
        try await checkSystemRequirements(for: model)
        
        // Check available disk space and cleanup if needed
        let resources = try await getAvailableResources()
        let requirements = configBuilder.getModelRequirements(for: model) ?? (ram: 0, disk: 0)
        
        if resources.disk < requirements.disk * 2 { // Ensure 2x space for safety
            try await cleanupUnusedModels()
            // Recheck space after cleanup
            let updatedResources = try await getAvailableResources()
            if updatedResources.disk < requirements.disk * 2 {
                throw LocalModelError.insufficientResources(required: (ram: requirements.ram, disk: requirements.disk * 2))
            }
        }
        
        // Update status to downloading
        modelStatuses[model] = .downloading(progress: 0.0)
        
        do {
            // Check disk cache first
            if let cachedData = modelCache.getCachedModel(model) {
                modelStatuses[model] = .ready
                recordModelUse(model)
                return
            }
            
            // Execute Ollama pull command and cache result
            try await executeOllamaPull(model)
            
            // Cache the downloaded model data
            if let modelData = try? await fetchModelData(model) {
                try modelCache.cacheModel(model, data: modelData)
            }
            
            modelStatuses[model] = .ready
            recordModelUse(model)
        } catch {
            modelStatuses[model] = .error(error.localizedDescription)
            throw LocalModelError.downloadFailed(error.localizedDescription)
        }
    }
    
    private func fetchModelData(_ model: String) async throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/ollama")
        process.arguments = ["show", model]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0,
              let data = try pipe.fileHandleForReading.readToEnd() else {
            throw LocalModelError.downloadFailed("Failed to fetch model data")
        }
        
        return data
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
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up async stream to read output
        let outputStream = AsyncStream<String> { continuation in
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                guard let line = String(data: handle.availableData, encoding: .utf8) else { return }
                if !line.isEmpty {
                    continuation.yield(line)
                }
            }
        }
        
        // Start the process
        try process.run()
        
        // Process output and update progress
        for await line in outputStream {
            if let progress = parseDownloadProgress(from: line) {
                modelStatuses[model] = .downloading(progress: progress)
            }
            // Check for specific error patterns
            if line.contains("error") || line.contains("failed") {
                throw LocalModelError.downloadFailed(line)
            }
        }
        
        // Wait for process completion
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw LocalModelError.downloadFailed(errorMessage)
        }
    }
    
    private func getAvailableResources() async throws -> (ram: Int, disk: Int) {
        // Get available RAM
        var stats = vm_statistics64()
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { pointer in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, pointer, &size)
            }
        }
        
        guard result == KERN_SUCCESS else {
            throw LocalModelError.downloadFailed("Failed to get system memory info")
        }
        
        let availableRAM = Int(stats.free_count) * Int(vm_page_size)
        
        // Get available disk space
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        guard let storage = try? fileURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
              let availableDiskSpace = storage.volumeAvailableCapacity else {
            throw LocalModelError.downloadFailed("Failed to get available disk space")
        }
        
        return (ram: availableRAM, disk: Int(availableDiskSpace))
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
    
    private func parseDownloadProgress(from line: String) -> Double? {
        // Example progress line: "downloading: [=====================>             ] 70.12%"
        if line.contains("%") {
            let components = line.components(separatedBy: " ")
            if let percentStr = components.last?.replacingOccurrences(of: "%", with: ""),
               let percent = Double(percentStr) {
                return percent / 100.0
            }
        }
        return nil
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
