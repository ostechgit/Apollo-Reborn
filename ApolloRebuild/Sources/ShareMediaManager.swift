import Foundation
import UIKit

// ShareMediaManager - handles sharing media from the app
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ShareMediaManager {
    
    static let shared = ShareMediaManager()
    
    private init() {}
    
    func shareImage(image: UIImage, title: String, fromViewController viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [image, title],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        
        viewController.present(activityVC, animated: true, completion: nil)
    }
    
    func shareURL(url: URL, title: String, fromViewController viewController: UIViewController) {
        let activityVC = UIActivityViewController(
            activityItems: [url, title],
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
        }
        
        viewController.present(activityVC, animated: true, completion: nil)
    }
}
