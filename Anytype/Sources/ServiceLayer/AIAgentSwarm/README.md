# AI Agent Swarm System

A local, efficient system for handling metadata enrichment, configuration optimization, and content analysis tasks within the iOS app.

## Core Features

- **Local Processing**: All agents run locally within the app
- **Resource Management**: Intelligent task queuing and memory monitoring
- **Priority-based Execution**: Tasks are processed based on importance and system state
- **Result Caching**: Efficient caching of recent results to prevent duplicate work
- **Automatic Recovery**: Graceful handling of timeouts and system pressure

## Components

### 1. Agents
- `MetadataEnricherAgent`: Enhances object metadata using AI analysis
- `ConfigurationManagerAgent`: Optimizes settings and configurations

### 2. Task Management
- `AITaskQueueManager`: Handles task queuing, execution, and resource management
- `AITaskPrioritizer`: Determines task priority and execution parameters
- Automatic task timeout based on priority:
  - Critical: 10 seconds
  - High: 20 seconds
  - Medium: 30 seconds
  - Low: 45 seconds

### 3. Integration
- `AIAgentSwarmService`: Main service interface
- `AIAgentSwarmView`: SwiftUI interface
- `AIAgentSwarmActionButton`: Reusable UI component

## Usage

### Basic Implementation
```swift
// In your view
var body: some View {
    VStack {
        // Your content
        AIAgentSwarmActionButton(objectId: objectId)
    }
}
```

### Custom Agent Creation
```swift
final class CustomAgent: AIAgent {
    let id: String = UUID().uuidString
    let type: AIAgentType = .yourType
    private(set) var status: AIAgentStatus = .idle
    
    func process(task: AITask) async throws -> AITaskResult {
        // Your processing logic
    }
}
```

## Resource Management

### Memory Usage
- Monitors system memory usage
- Automatically adjusts task priorities under pressure
- Cleans cache when memory usage exceeds 80%

### Task Queuing
- Maximum 3 concurrent tasks
- Priority-based queue ordering
- Automatic task cancellation on timeout

## Best Practices

1. **Task Priority**
   - Use appropriate task types for correct prioritization
   - Consider system state for resource-intensive tasks
   - Implement retry logic for critical operations

2. **Cache Management**
   - Cache results expire after 5 minutes
   - Implement cleanup for expired entries
   - Force cache cleanup under memory pressure

3. **Error Handling**
   - Implement proper error recovery
   - Provide user feedback for failures
   - Log important errors for debugging

## Extension Points

### Adding New Agent Types
1. Add new case to `AIAgentType`
2. Create new agent class implementing `AIAgent`
3. Register agent in `AIAgentSwarm.setupDefaultAgents()`

### Custom Task Types
1. Add new case to `AITaskType`
2. Update `AITaskPrioritizer` priority logic
3. Implement handling in appropriate agent

## Performance Considerations

- Monitor memory usage with `getMemoryUsage()`
- Use appropriate timeout values
- Implement proper cleanup in agents
- Cache results when appropriate
- Cancel unnecessary operations

## Debug Tools

- Queue status monitoring
- Agent state tracking
- Task priority inspection
- Memory usage monitoring

## Future Improvements

- Additional agent types
- Enhanced prioritization logic
- Improved caching strategies
- Better resource monitoring
- Cross-object optimization

## Contributing

1. Follow existing patterns
2. Add proper documentation
3. Consider resource implications
4. Test thoroughly
5. Update relevant documentation
