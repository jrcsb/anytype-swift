import Foundation
import Services
import Combine

final class AIObjectChangeObserver {
    @Injected(\.aiAutoConfigTrigger)
    private var configTrigger: AIAutoConfigurationTrigger
    
    private var subscriptions = Set<AnyCancellable>()
    private var contentCache: [String: String] = [:] // objectId: content
    
    init() {
        setupObjectObservers()
    }
    
    private func setupObjectObservers() {
        // Subscribe to object creation notifications
        NotificationCenter.default.publisher(for: .objectDidCreate)
            .compactMap { notification -> (String, String)? in
                guard let userInfo = notification.userInfo,
                      let objectId = userInfo["objectId"] as? String,
                      let content = userInfo["content"] as? String else {
                    return nil
                }
                return (objectId, content)
            }
            .sink { [weak self] objectId, content in
                Task {
                    await self?.handleObjectCreated(objectId: objectId, content: content)
                }
            }
            .store(in: &subscriptions)
        
        // Subscribe to object modification notifications
        NotificationCenter.default.publisher(for: .objectDidModify)
            .compactMap { notification -> (String, String)? in
                guard let userInfo = notification.userInfo,
                      let objectId = userInfo["objectId"] as? String,
                      let content = userInfo["content"] as? String else {
                    return nil
                }
                return (objectId, content)
            }
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main) // Debounce rapid changes
            .sink { [weak self] objectId, content in
                Task {
                    await self?.handleObjectModified(objectId: objectId, content: content)
                }
            }
            .store(in: &subscriptions)
    }
    
    private func handleObjectCreated(objectId: String, content: String) async {
        contentCache[objectId] = content
        await configTrigger.handleObjectCreated(objectId, content: content)
    }
    
    private func handleObjectModified(objectId: String, content: String) async {
        let previousContent = contentCache[objectId]
        contentCache[objectId] = content
        await configTrigger.handleObjectModified(objectId, content: content, previousContent: previousContent)
    }
    
    func clearCache(for objectId: String) {
        contentCache.removeValue(forKey: objectId)
        configTrigger.clearConfigurationHistory(for: objectId)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let objectDidCreate = Notification.Name("objectDidCreate")
    static let objectDidModify = Notification.Name("objectDidModify")
}
