import Foundation

actor AITaskQueueManager {
    // Maximum number of concurrent tasks
    private let maxConcurrentTasks = 3
    
    // Task prioritizer
    private let prioritizer: AITaskPrioritizer
    
    // Current tasks in progress
    private var activeTasks: [String: Task<AITaskResult, Error>] = [:]
    
    // Queue of pending tasks with priority
    private var pendingTasks: [(task: AITask, priority: TaskPriority, continuation: CheckedContinuation<AITaskResult, Error>)] = []
    
    init() {
        self.prioritizer = AITaskPrioritizer(systemStateProvider: { [weak self] in
            guard let self = self else { return 0.0 }
            return self.getMemoryUsage()
        })
    }
    
    // Cache for recent results
    private var resultCache: [String: (result: AITaskResult, timestamp: Date)] = [:]
    private let cacheDuration: TimeInterval = 300 // 5 minutes
    
    func enqueueTask(_ task: AITask) async throws -> AITaskResult {
        // Check cache first
        if let cachedResult = getCachedResult(for: task) {
            return cachedResult
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let priorityInfo = prioritizer.getPriorityInfo(for: task)
            
            if activeTasks.count < maxConcurrentTasks {
                startTask(task, priorityInfo: priorityInfo, continuation: continuation)
            } else {
                // Insert task in priority order
                let index = pendingTasks.firstIndex { $0.priority <= priorityInfo.priority } ?? pendingTasks.count
                pendingTasks.insert((task, priorityInfo.priority, continuation), at: index)
            }
        }
    }
    
    private func startTask(_ task: AITask, priorityInfo: TaskPriorityInfo, continuation: CheckedContinuation<AITaskResult, Error>) {
        let task = Task {
            do {
                // Add artificial delay to prevent overwhelming system
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Process task
                let result = try await processTask(task)
                
                // Cache result
                cacheResult(result, for: task)
                
                return result
            } catch {
                throw error
            }
        }
        
        activeTasks[task.id] = task
        
        // Handle task completion
        Task {
            do {
                let result = try await task.value
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
            
            // Clean up and start next task
            await taskCompleted(taskId: task.id)
        }
    }
    
    private func taskCompleted(taskId: String) {
        activeTasks[taskId] = nil
        
        // Start next pending task if available
        if let nextTask = pendingTasks.first {
            pendingTasks.removeFirst()
            startTask(nextTask.0, continuation: nextTask.1)
        }
    }
    
    private func processTask(_ task: AITask) async throws -> AITaskResult {
        // Get the swarm instance through dependency injection
        let swarm = Container.shared.aiAgentSwarmService()
        
        do {
            // Monitor memory usage
            let memoryUsage = getMemoryUsage()
            if memoryUsage > 0.8 { // 80% threshold
                cleanCache() // Force cache cleanup
            }
            
            // Process the task
            return try await withThrowingTaskGroup(of: AITaskResult.self) { group in
                // Add task to group with timeout
                group.addTask {
                    try await withTimeout(seconds: priorityInfo.timeout) {
                        let result = try await swarm.processTask(task)
                        return result
                    }
                }
                
                // Wait for first (and only) result
                return try await group.next() ?? AITaskResult(
                    taskId: task.id,
                    status: .failed,
                    result: [:],
                    error: AISwarmError.processingFailed
                )
            }
        } catch {
            throw error
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw AISwarmError.processingFailed
            }
            
            // Return first completed result, cancel remaining
            guard let result = try await group.next() else {
                throw AISwarmError.processingFailed
            }
            
            // Cancel any remaining tasks
            group.cancelAll()
            
            return result
        }
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / Double(ProcessInfo.processInfo.physicalMemory)
        }
        
        return 0.0
    }
    
    private func getCachedResult(for task: AITask) -> AITaskResult? {
        guard let cached = resultCache[task.id] else { return nil }
        
        // Check if cache is still valid
        if Date().timeIntervalSince(cached.timestamp) > cacheDuration {
            resultCache[task.id] = nil
            return nil
        }
        
        return cached.result
    }
    
    private func cacheResult(_ result: AITaskResult, for task: AITask) {
        resultCache[task.id] = (result, Date())
        
        // Clean old cache entries
        cleanCache()
    }
    
    private func cleanCache() {
        let now = Date()
        resultCache = resultCache.filter { (_, value) in
            now.timeIntervalSince(value.timestamp) <= cacheDuration
        }
    }
    
    func cancelAllTasks() {
        activeTasks.values.forEach { $0.cancel() }
        activeTasks.removeAll()
        pendingTasks.removeAll()
    }
    
    func getQueueStatus() -> AIQueueStatus {
        AIQueueStatus(
            activeTasks: activeTasks.count,
            pendingTasks: pendingTasks.count,
            cachedResults: resultCache.count
        )
    }
}

struct AIQueueStatus {
    let activeTasks: Int
    let pendingTasks: Int
    let cachedResults: Int
}
