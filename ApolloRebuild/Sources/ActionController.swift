import UIKit

// ActionController - manages actions on posts and comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ActionController {
    
    static let shared = ActionController()
    
    private init() {}
    
    // Show an action sheet with the given actions
    func showActionSheet(actions: [Action], fromViewController viewController: UIViewController) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        for action in actions {
            let alertAction = UIAlertAction(title: action.title, style: action.style.toUIAlertActionStyle()) { _ in
                action.handler(action)
            }
            
            if let icon = action.icon {
                // Set image on the action (iOS 15+)
                if #available(iOS 15.0, *) {
                    alertAction.setValue(UIImage(systemName: icon), forKey: "image")
                }
            }
            
            alert.addAction(alertAction)
        }
        
        // Add cancel action
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
}

// Action model
struct Action {
    let title: String
    let icon: String?
    let style: ActionStyle
    let handler: (Action) -> Void
}

enum ActionStyle {
    case `default`
    case destructive
    case cancel
    
    func toUIAlertActionStyle() -> UIAlertAction.Style {
        switch self {
        case .default:
            return .default
        case .destructive:
            return .destructive
        case .cancel:
            return .cancel
        }
    }
}
