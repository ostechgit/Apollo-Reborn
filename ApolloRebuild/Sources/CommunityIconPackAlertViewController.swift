import UIKit

// CommunityIconPackAlertViewController - shows alert for community icon packs
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CommunityIconPackAlertViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.systemBackground
        
        let alert = UIAlertController(
            title: "Community Icon Pack",
            message: "Would you like to use the community icon pack?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: nil))
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}
