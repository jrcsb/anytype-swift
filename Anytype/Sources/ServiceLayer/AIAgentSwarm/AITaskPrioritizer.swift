import Foundation

enum TaskPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct TaskPriorityInfo {
    let priority: TaskPriority
    let timeout: TimeInterval
    let retryCount: Int
}

final class AITaskPrioritizer {
    private let systemStateProvider: () -> Double // Memory usage provider
    
    init(systemStateProvider: @escaping () -> Double) {
        self.systemStateProvider = systemStateProvider
    }
    
    func getPriorityInfo(for task: AITask) -> TaskPriorityInfo {
        let basePriority = getBasePriority(for: task.type)
        let adjustedPriority = adjustForSystemState(basePriority)
        
        return TaskPriorityInfo(
            priority: adjustedPriority,
            timeout: getTimeout(for: adjustedPriority),
            retryCount: getRetryCount(for: adjustedPriority)
        )
    }
    
    private func getBasePriority(for taskType: AITaskType) -> TaskPriority {
        switch taskType {
        case .enrichMetadata:
            return .medium
        case .augmentContent:
            return .low
        case .configureSettings:
            return .high
        case .analyzeContent:
            return .medium
        }
    }
    
    private func adjustForSystemState(_ basePriority: TaskPriority) -> TaskPriority {
        let memoryUsage = systemStateProvider()
        
        // Under high memory pressure, downgrade priorities
        if memoryUsage > 0.8 { // 80% memory usage
            switch basePriority {
            case .critical:
                return .high
            case .high:
                return .medium
            case .medium:
                return .low
            case .low:
                return .low
            }
        }
        
        return basePriority
    }
    
    private func getTimeout(for priority: TaskPriority) -> TimeInterval {
        switch priority {
        case .critical:
            return 10 // 10 seconds
        case .high:
            return 20 // 20 seconds
        case .medium:
            return 30 // 30 seconds
        case .low:
            return 45 // 45 seconds
        }
    }
    
    private func getRetryCount(for priority: TaskPriority) -> Int {
        switch priority {
        case .critical:
            return 3
        case .high:
            return 2
        case .medium:
            return 1
        case .low:
            return 0
        }
    }
}
