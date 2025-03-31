import SwiftUI
import Services

protocol AIAgentSwarmCoordinatorProtocol {
    func showAgentSwarm(for objectId: String)
    func hideAgentSwarm()
}

final class AIAgentSwarmCoordinator: AIAgentSwarmCoordinatorProtocol {
    @Injected(\.aiConfigBuilder)
    private var configBuilder: any AIConfigBuilderProtocol
    
    private weak var hostingController: UIHostingController<AIAgentSwarmView>?
    
    func showAgentSwarm(for objectId: String) {
        // Check if AI configuration is available
        guard configBuilder.makeOpenAIConfig() != nil else {
            anytypeAssertionFailure("AI configuration is not available")
            return
        }
        
        let view = AIAgentSwarmView(objectId: objectId)
        let hostingController = UIHostingController(rootView: view)
        
        // Configure presentation style
        hostingController.modalPresentationStyle = .formSheet
        hostingController.isModalInPresentation = false
        
        // Store reference for dismissal
        self.hostingController = hostingController
        
        // Present the view
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let topViewController = windowScene.windows.first?.rootViewController?.topMostViewController {
            topViewController.present(hostingController, animated: true)
        }
    }
    
    func hideAgentSwarm() {
        hostingController?.dismiss(animated: true)
        hostingController = nil
    }
}

// Helper extension to find top view controller
private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController ?? tab
        }
        return self
    }
}
