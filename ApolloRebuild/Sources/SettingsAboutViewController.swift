import UIKit

// SettingsAboutViewController - shows the about page in settings
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SettingsAboutViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "About"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Apollo 1.15.11\n\nA Reddit client for iOS\n\nBuilt with love by the Apollo team"
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
