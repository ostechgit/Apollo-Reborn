import UIKit

// ApolloUltraManagementViewController - manages Apollo Ultra subscription
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ApolloUltraManagementViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Manage Ultra"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Manage your Apollo Ultra subscription"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        
        self.view.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 100),
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16)
        ])
    }
}
