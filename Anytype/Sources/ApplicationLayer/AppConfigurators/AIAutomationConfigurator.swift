import Foundation
import Services

final class AIAutomationConfigurator: AppConfiguratorProtocol {
    @Injected(\.aiAutomationService)
    private var automationService: any AIAutomationServiceProtocol
    
    func configure() {
        // Start automation service
        automationService.startAutomation()
        
        // Set up lifecycle observers
        setupLifecycleObservers()
    }
    
    private func setupLifecycleObservers() {
        // Observe app entering background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let service = self?.automationService as? AIAutomationService else { return }
            service.handleAppBackground()
        }
        
        // Observe memory warnings
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let service = self?.automationService as? AIAutomationService else { return }
            service.handleMemoryWarning()
        }
        
        // Observe app termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.automationService.stopAutomation()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
